# need powershell 7 !!!
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
$project = 'nxsample'
if (!$args[0] -eq '') { $project = $args[0] }
    
npm install -g npm@latest @angular/cli nx
npx create-nx-workspace $project --appName=$project --preset=angular-monorepo --style=css --nxClud=false

Remove-Item -LiteralPath $project/apps/$project-e2e -Force -Recurse

Set-Location -Path ./$project

# add primeng to package.json
    $packageJson = Get-Content ./package.json -Raw | ConvertFrom-Json 

    $primengResponse = Invoke-WebRequest -URI https://registry.npmjs.org/primeng
    $primengInfo = ConvertFrom-Json $primengResponse.Content
    $primengVersion = $primengInfo.'dist-tags'.latest
    $packageJson.dependencies | add-member -Name "primeng" -value "^$primengVersion" -MemberType NoteProperty

    $primeiconsResponse = Invoke-WebRequest -URI https://registry.npmjs.org/primeicons 
    $primeiconsInfo = ConvertFrom-Json $primeiconsResponse.Content
    $primeiconsVersion = $primeiconsInfo.'dist-tags'.latest
    $packageJson.dependencies | add-member -Name "primeicons" -value "^$primeiconsVersion" -MemberType NoteProperty

    $packageJson | ConvertTo-Json -Depth 100  | set-content ./package.json  

# -------------------

Set-Location -Path ./apps/$project

# set styles
    $projectJson = Get-Content ./project.json -Raw | ConvertFrom-Json 

    $styles = @('node_modules/primeicons/primeicons.css') + `
            @('node_modules/primeng/resources/themes/lara-light-blue/theme.css') + `
            @('node_modules/primeng/resources/primeng.min.css') + `
            $projectJson.targets.build.options.styles
    $projectJson.targets.build.options.styles = $styles

    $projectJson | ConvertTo-Json -Depth 100  | set-content ./project.json  

# new imports into app.module
    $rows = New-Object System.Collections.Generic.List[System.Object]
    foreach ($row in Get-Content -Path ./src/app/app.module.ts) { 
        if ($row -like "*imports*" -and $row -like "*[BrowserModule]*") {
            $rows.Add("  imports: [")
            $rows.Add("    BrowserModule,")
            $rows.Add("    FormsModule,")
            $rows.Add("    HttpClientModule,")
            $rows.Add("    BrowserAnimationsModule,")
            $rows.Add("");
            $rows.Add("    MenubarModule,")
            $rows.Add("    TieredMenuModule,")
            $rows.Add("    InputTextModule,")
            $rows.Add("    ButtonModule,")
            $rows.Add("    PasswordModule,")
            $rows.Add("    MessagesModule,")
            $rows.Add("    MessageModule,")
            $rows.Add("");
            $rows.Add("    AppRoutingModule,")
            $rows.Add("  ],")
        }
        else {
            $rows.Add($row)
            if ($row -like '*BrowserModule*') {
                $rows.Add("import { FormsModule } from '@angular/forms';")
                $rows.Add("import { HttpClientModule } from '@angular/common/http';")
                $rows.Add("import { BrowserAnimationsModule } from '@angular/platform-browser/animations';")
                $rows.Add("")
                $rows.Add("import { MenubarModule } from 'primeng/menubar';")
                $rows.Add("import { TieredMenuModule } from 'primeng/tieredmenu';")
                $rows.Add("import { InputTextModule } from 'primeng/inputtext';")                
                $rows.Add("import { ButtonModule } from 'primeng/button';")
                $rows.Add("import { PasswordModule } from 'primeng/password';")
                $rows.Add("import { MessagesModule} from 'primeng/messages';")
                $rows.Add("import { MessageModule} from 'primeng/message';")
                $rows.Add("")
                $rows.Add("import { AppRoutingModule } from './app-routing.module';")
            }
        }
    }
    $rows | Set-Content ./src/app/app.module.ts
    
    # create environment files
        New-Item -Path './src/environments' -ItemType Directory
        $rows = New-Object System.Collections.Generic.List[System.Object]
        $rows.Add('export const environment = {')
        $rows.Add('  production: false,')
        $rows.Add('  apiURL: ''http://localhost:5001/api'',')
        $rows.Add('}')
        $rows | Set-Content ./src/environments/environment.ts

        $rows = New-Object System.Collections.Generic.List[System.Object]
        $rows.Add('export const environment = {')
        $rows.Add('  production: true,')
        $rows.Add('  apiURL: ''http://prodserver.company.com/api'',')
        $rows.Add('}')
        $rows | Set-Content ./src/environments/environment.prod.ts

        $settings = ConvertFrom-Json '[{"replace": "src/environments/environment.ts","with": "src/environments/environment.prod.ts"}]'     
        $projectJson = Get-Content ./project.json -Raw | ConvertFrom-Json 
        $projectJson.targets.build.configurations.production | Add-Member "fileReplacements" -value @($settings) -MemberType NoteProperty
        $projectJson.targets.build.configurations.production.fileReplacements[0].with
        $projectJson | ConvertTo-Json -Depth 100  | set-content ./project.json  

# Create component folder
    New-Item -Path './src/app/components' -ItemType Directory 

# Move AppComponent to component folder
    Remove-Item -Path './src/app/*.spec.ts'
    Move-Item -Path './src/app/app.component.*' -Destination './src/app/components'
    'export * from ''./app.component'';' | Set-Content ./src/app/components/index.ts
    
    $rows = New-Object System.Collections.Generic.List[System.Object]
    foreach ($row in Get-Content -Path ./src/app/app.module.ts) { 
        if ($row -like '*AppComponent*' -and $row -like '*from*') {
            $rows.Add('import { ')
            $rows.Add('  AppComponent')
            $rows.Add('} from ''./components'';')
        }
        elseif ($row -like '*declarations*') {
            $rows.Add('  declarations: [')
            $rows.Add('    AppComponent')
            $rows.Add('  ],')
        }
        elseif ($row -like "*NxWelcomeComponent*") {
            #do nothing
        }
        else {
            $rows.Add($row)
        }
    }
    $rows | Set-Content ./src/app/app.module.ts

#create common components (Home, Login, Menu ... ) 
    Set-Location -Path ./src/app/components
    New-Item -Path './common' -ItemType Directory
    Set-Location -Path ./common

    ng g c home --skip-import --skip-tests
    ng g c menu --skip-import --skip-tests
    ng g c login --skip-import --skip-tests
    'export * from ''./home/home.component'';' | Set-Content ./index.ts
    Add-Content ./index.ts 'export * from ''./menu/menu.component'';'
    Add-Content ./index.ts 'export * from ''./login/login.component'';'

# create dummy components
    Set-Location -Path ..
    Add-Content ./index.ts 'export * from ''./common'';'
    ng g c first --skip-import --skip-tests
    ng g c second --skip-import --skip-tests
    ng g c protected-third --skip-import --skip-tests
    ng g c protected-fourth --skip-import --skip-tests
    Add-Content ./index.ts 'export * from ''./first/first.component'';'
    Add-Content ./index.ts 'export * from ''./second/second.component'';'
    Add-Content ./index.ts 'export * from ''./protected-third/protected-third.component'';'
    Add-Content ./index.ts 'export * from ''./protected-fourth/protected-fourth.component'';'

Set-Location -Path ..
    
# create models
    New-Item -Path './models' -ItemType Directory
    Set-Location -Path ./models
    @'
export interface UserModel {
    loginName: string;
    name: string;
    token: string;
}
'@ | Set-Content ./user.model.ts

    @'
export interface LoginModel {
    loginName: string;
    password: string;
}
'@ | Set-Content ./login.model.ts

    'export * from ''./user.model'';' | Set-Content ./index.ts
    Add-Content ./index.ts 'export * from ''./login.model'';'

Set-Location -Path ..

# create services
    New-Item -Path './services' -ItemType Directory
    Set-Location -Path ./services
    @'
import { EventEmitter, Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { Observable, of, throwError } from 'rxjs';

import { 
  UserModel,
  LoginModel
} from '../models';

@Injectable({
  providedIn: 'root'
})
export class AuthService {

  constructor(
    private http: HttpClient,
    private router: Router) { }

  private _signedUser: UserModel | null = null;
  signedUserChanged = new EventEmitter<UserModel | null>();

  get signedUser(): UserModel | null {
    return this._signedUser;
  }

  set signedUser(value: UserModel | null)  {
    this._signedUser = value;
    this.signedUserChanged.emit(value);
  }

  get isSignedIn(): boolean {
    return this._signedUser != null;
  }

  signIn(model: LoginModel): Observable<UserModel> {
    if (model.loginName == 'admin' && model.password == 'admin') {
      const result: UserModel = {
        loginName: model.loginName,
        name: 'John Doe',
        token: 'asdfghjklqwertzuiopy'
      }
      this.signedUser = result;
      return of(result);
    } else {
      this.signedUser = null;
      return throwError(() => new Error('Invalid login name or password'));
    }
  }

  signOut(): void {
    this.signedUser = null;
    this.router.navigate(['/']);
  }
}
'@ | Set-Content ./auth.service.ts
    'export * from ''./auth.service'';' | Set-Content ./index.ts


Set-Location -Path ..

# add new components to app.module
    $rows = New-Object System.Collections.Generic.List[System.Object]
    foreach ($row in Get-Content -Path ./app.module.ts) { 
        if ($row -like '*AppComponent') {
            $rows.Add("    AppComponent,");
            $rows.Add("    HomeComponent,");
            $rows.Add("    MenuComponent,");
            $rows.Add("    LoginComponent,");
            $rows.Add("    FirstComponent,");
            $rows.Add("    SecondComponent,");
            $rows.Add("    ProtectedThirdComponent,");
            $rows.Add("    ProtectedFourthComponent,");
        }
        else {
            $rows.Add($row)
        }
    }
    $rows | Set-Content ./app.module.ts

# Set routing 
@'
import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { AuthGuard } from './auth.guard';
import {
    HomeComponent,
    LoginComponent,
    FirstComponent,
    SecondComponent,
    ProtectedThirdComponent,
    ProtectedFourthComponent
} from './components';

const routes: Routes = [
    { path: '', component: HomeComponent },
    { path: 'login', component: LoginComponent },
    { path: 'first', component: FirstComponent },
    { path: 'second', component: SecondComponent },    
    { path: 'third', component: ProtectedThirdComponent, canActivate: [AuthGuard] },    
    { path: 'fourth', component: ProtectedFourthComponent, canActivate: [AuthGuard] },    
];

@NgModule({
    imports: [RouterModule.forRoot(routes)],
    exports: [RouterModule]
})
export class AppRoutingModule { } 
'@  | Set-Content ./app-routing.module.ts

#auth.guard.ts

@'
/* eslint-disable @typescript-eslint/no-unused-vars */
import { Injectable } from '@angular/core';
import { 
  ActivatedRouteSnapshot, 
  CanActivate, 
  RouterStateSnapshot, 
  UrlTree,
  Router 
} from '@angular/router';
  import { Observable } from 'rxjs';
  import { AuthService } from './services';

@Injectable({
  providedIn: 'root'
})
export class AuthGuard implements CanActivate {
  
  constructor (
    private authService: AuthService,
    private router: Router) {}

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot): Observable<boolean | UrlTree> | Promise<boolean | UrlTree> | boolean | UrlTree {
      if (this.authService.isSignedIn) {
        let result = false;
        switch (state.url) {
          case '/third':
            result = true;
            break;
          case '/fourth':
            result = true;
            break;
          default:
            break;
        }
        return result;
      } else {
        this.router.navigate(['/login'], {queryParams: {returnUrl: state.url}});
        return false;
      }
  } 
}
'@  | Set-Content ./auth.guard.ts

# set style.css content
@'
.cursor-pointer {
    cursor: pointer;
}
'@ | Set-Content ./../styles.css

# set app.component.html content
@'
<div class="content">
    <{0}-menu></{0}-menu>
    <router-outlet></router-outlet>
</div>
'@ -f $project | Set-Content ./components/app.component.html

# set app.component.css content
    @'
.content {
    width: 100%;
    max-width: 1280px;
    margin: 0 auto;
}
'@ | Set-Content ./components/app.component.css

# set app.component.ts content
    @"
import { Component } from '@angular/core';

@Component({
  selector: '$($project)-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent {
}
"@ | Set-Content ./components/app.component.ts

$projectName = $project.substring(0,1).toupper()+$project.substring(1).tolower()
# set menu.component.html content
    @'
<p-menubar [model]="menuItems">
    <ng-template pTemplate="start">
        <a class="project-name" routerLink="/">Nxsample project</a>
    </ng-template>
    <ng-template pTemplate="end">
        <a *ngIf="!signedUser" routerLink="/login">Sign in</a>
        <span *ngIf="signedUser" (click)="usermenu.toggle($event)" class="cursor-pointer">{{{{signedUser.name}}}}</span>
        <p-tieredMenu #usermenu [model]="usermenuItems" [popup]="true"></p-tieredMenu>
    </ng-template>
</p-menubar>      
'@ -f $projectName | Set-Content ./components/common/menu/menu.component.html

# set menu.component.css content
@'
.project-name {
    margin-left: 0.5rem;
    margin-right: 0.5rem;
    font-size: 1.25rem;
    font-weight: bold;
}

a {
    color: unset;
    text-decoration: none;
}
'@ | Set-Content ./components/common/menu/menu.component.css

# set menu.component.ts contet 
    @"
import { Component, OnInit } from '@angular/core';
import { MenuItem } from 'primeng/api';
import { UserModel } from '../../../models';
import { AuthService } from '../../../services';

@Component({
    selector: '$($project)-menu',
    templateUrl: './menu.component.html',
    styleUrls: ['./menu.component.css']
})
export class MenuComponent implements OnInit {
    menuItems: MenuItem[] = [];
    usermenuItems: MenuItem[] = [];
    signedUser: UserModel | null = null;

    constructor(private authService: AuthService) {}

    ngOnInit(): void {
        this.setMenuItems();     
        this.authService.signedUserChanged.subscribe({
            next: (user: UserModel | null) => {
                this.signedUser = user;
                this.setMenuItems();
            }
        });
    }

    setMenuItems(): void {
        this.usermenuItems = [
            {
                label: 'Sign out',
                command: () => this.authService.signOut()
            }
        ];
        
        this.menuItems = [
            {
                label:'Functions',
                items:[
                    {
                        label:'First',
                        routerLink: '/first'
                    },
                    {
                        separator:true
                    },
                    {
                        label:'Second',
                        routerLink: '/second'
                    }
                ]
            },
            {
                label:'Protected',
                visible: this.signedUser != null,
                items:[
                    {
                        label:'Third',
                        routerLink: '/third',
                        visible: this.signedUser != null
                    },
                    {
                        separator:true
                    },
                    {
                        label:'Fourth',
                        routerLink: '/fourth',
                        visible: this.signedUser != null
                    }
                ]
            }
        ];
    }
} 
"@ | Set-Content ./components/common/menu/menu.component.ts

# set login.component.html content
@'
<form class="container" (submit)="submit()">
    <div>
        <input type="text" pInputText placeholder="login name"
            [class]="submitted && !user.loginName ? 'ng-invalid ng-dirty' : ''" [(ngModel)]="user.loginName"
            name="loginName">
    </div>
    <div>
        <p-password placeholder="password" [feedback]="false" [toggleMask]="true" [(ngModel)]="user.password"
            name="password" [class]="submitted && !user.password ? 'ng-invalid ng-dirty' : ''">
        </p-password>
    </div>
    <div>
        <button *ngIf="errorMessages.length == 0" pButton type="submit" label="Sign in" class="p-button"></button>
        <p-messages [(value)]="errorMessages" [enableService]="false" [showTransitionOptions]="'0ms'"
            [hideTransitionOptions]="'0ms'"></p-messages>
    </div>
</form>  
'@ | Set-Content ./components/common/login/login.component.html

# set login.component.css content
@'
.container {
    width: 400px;
    margin: 0 auto;
    background-color: #ddd;
    padding: 2rem;
    border-radius: 1rem;
    margin-top: 10vh;
    
    display: flex;
    flex-direction: column;
    align-items: center;  
    gap: 1rem;
}

input, :host ::ng-deep .p-password input  {
    width: 300px;
}

:host ::ng-deep .p-message {
    margin-top:0;
    margin-bottom: 0;
}

:host ::ng-deep .p-message-wrapper {
    padding: 8px 12px;    
}
'@ | Set-Content ./components/common/login/login.component.css

# set login.component.ts contet 
    @"
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { Message } from 'primeng/api';

import { LoginModel } from '../../../models';
import { AuthService } from '../../../services';

@Component({
  selector: '$($project)-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css']
})
export class LoginComponent implements OnInit{

  submitted = false;
  errorMessages: Message[] = [];
  returnUrl = '/';

  user: LoginModel = {
    loginName: 'admin',
    password: 'admin',
  }

  constructor(
    private authService: AuthService,
    private router: Router,
    private route: ActivatedRoute) {}
  
  ngOnInit(): void {
    this.returnUrl = this.route.snapshot.queryParams['returnUrl'] || '/';
  }

  submit(): void {
    this.submitted = true;
    if (this.user.loginName && this.user.password) {
      this.authService.signIn(this.user).subscribe({
        next: () => {
          this.router.navigateByUrl(this.returnUrl);
        },
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        error: (err: any) => {
          this.errorMessages= [{severity: 'error', detail: err}];
          // console.log(err)
        }
      })

    }
  }
}     
"@  | Set-Content ./components/common/login/login.component.ts

Set-Location -Path ../..
Set-Location -Path ../..
npm i
code ./
start-process "cmd.exe" "/c nx serve --project $($project) --open" 
Set-Location -Path ..


