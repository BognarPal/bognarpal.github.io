function loadSourceCode(htmlElement, url, functionSignature) {
    url = 'https://raw.githubusercontent.com/BognarPal/' + url;
    var xhrSourceCode = new XMLHttpRequest();
    xhrSourceCode.addEventListener('readystatechange', function () {
        if (this.readyState === 4) {
            if (functionSignature) {    
                var lines = this.responseText.split('\n');
                var sourceCode = '';
                var bracesCount = undefined;
                for (line of lines) {                    
                    if (line.indexOf(functionSignature) !== -1 || sourceCode) {
                        sourceCode += line + '\n';
                        bracesCountChange = (line.split('{').length - 1) - (line.split('}').length - 1);
                        if (bracesCountChange !== 0) {
                            if (bracesCount == undefined ) {
                                bracesCount = bracesCountChange;
                            } else {
                                bracesCount += bracesCountChange;
                                if (bracesCount === 0)
                                    break;
                            }
                        }
                    }
                };
                htmlElement.innerHTML = hljs.highlightAuto(sourceCode).value;
            } else {                
                htmlElement.innerHTML = hljs.highlightAuto(this.responseText).value;
            }
            location.href = location.href;
        }
    });

    xhrSourceCode.open('GET', url);
    xhrSourceCode.overrideMimeType('text/plain; charset=iso-8859-1');
    xhrSourceCode.send();
}  

function loadContent(page) {    
    var gotoToId = '#';
    if (page.indexOf('#') !== -1 ) {
        gotoToId = page.substr(page.indexOf('#'), page.length);
        page = page.substr(0, page.indexOf('#'));
    }

    var rootMenuElement = document.querySelector('#sidebar p[data-page="' + page + '"]');
    if (!rootMenuElement) {
        page = 'feladatDefinicio';
        loadContent(page);
        return;
    }
    document.title = 'Pizzéria: ' + rootMenuElement.attributes['data-title'].value;

    document.querySelectorAll('div#sidebar p[class~="small"]').forEach(element => {
        if (element.attributes['data-page'].value.indexOf(page) === -1) {
            element.style.display = 'none';
        } else {
            element.style.display = null;
        }
    });

    var selectedMenuElement = rootMenuElement;
    if (gotoToId !='#') {
        selectedMenuElement = document.querySelector('#sidebar p[data-page="' + page + gotoToId + '"]')
        if (!selectedMenuElement) {
            selectedMenuElement = rootMenuElement;
            gotoToId = '#';
        }
    }
    document.querySelectorAll('#sidebar p[data-page]').forEach( element => {
        element.style.fontWeight = "normal";
        element.style.color = "#eee";
    });
    selectedMenuElement.style.fontWeight = "bold";
    selectedMenuElement.style.color = "#6ee";

    history.pushState(null, '', '/pizzeria/main.html?page=' + page);

    if (selectedMenuElement.attributes['data-newPage']) {
        page = gotoToId.substring(1);
    }

    var xhrContent = new XMLHttpRequest();
    xhrContent.addEventListener('readystatechange', function () {
        if (this.readyState === 4) {
            if (this.status === 404) {
                document.querySelector('#content').innerHTML = `
                    <h3>${selectedMenuElement.attributes['data-title'].value}</h3>
                    <div class="text-center mt-5">
                        <img src="/img/under-construction.gif">
                    </div>
                `;
                location.href = gotoToId;
            } else {
                document.querySelector('#content').innerHTML = this.responseText;
                hljs.highlightAll();            
                location.href = gotoToId;

                document.querySelectorAll('pre code[data-url]').forEach( element => {
                    if (element.attributes['data-functionSignature']) {
                        loadSourceCode(element, element.attributes['data-url'].value, element.attributes['data-functionSignature'].value)
                    } else {
                        loadSourceCode(element, element.attributes['data-url'].value)
                    }
                });
            }
            
        }
    });    

    xhrContent.open('GET', page + '.html');
    xhrContent.send();
}        

var xhrSideBar = new XMLHttpRequest();
xhrSideBar.addEventListener('readystatechange', function () {
    if (this.readyState === 4) {
        document.querySelector('#sidebar').innerHTML = this.responseText;

        const urlSearchParams = new URLSearchParams(window.location.search);
        const params = Object.fromEntries(urlSearchParams.entries());
        var page = params['page'];
        if (!page) {
            page = 'feladatDefinicio'
        }    
    
        loadContent(page + window.location.hash);           
        
        document.getElementById('sidebar').addEventListener('click', (event) => {
            loadContent(event.target.attributes['data-page'].value);
        });
    }
});

xhrSideBar.open('GET', 'sidebar.html');
xhrSideBar.send();



