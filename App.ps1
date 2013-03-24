Import-Module ActiveDirectory -PSSession (New-PSSession -ComputerName win2008r2dc)

function New-GridView {
    param(
        [string[]]$Columns
    )

    $view = New-Object System.Windows.Controls.GridView
    foreach($column in $Columns) {
        $c = New-Object System.Windows.Controls.GridViewColumn
        $c.Header = $column
        $c.DisplayMemberBinding = New-Object System.Windows.Data.Binding -ArgumentList $column
        $view.Columns.Add($c)
    }
    $view
}

Add-Type -AssemblyName "PresentationFramework"

[xml]$xaml = Get-Content -Path (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath  "MainWindow.xaml")
$reader = New-Object System.Xml.XmlNodeReader $xaml 
[System.Windows.Window]$window = [System.Windows.Markup.XamlReader]::Load($reader)

$window.FindName("MainFrame").Source = (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath  "Admin.xaml")
[xml]$xaml = Get-Content -Path (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath  "Admin.xaml")
$reader = New-Object System.Xml.XmlNodeReader $xaml 
$window.Content = [System.Windows.Markup.XamlReader]::Load($reader)

$content = $window.Content

$txtComputerName = [System.Windows.Controls.TextBox]($content.FindName('txtComputerName'))
$txtComputerName.Text = $Env:COMPUTERNAME
$txtUserName = [System.Windows.Controls.TextBox]($content.FindName('txtUserName'))
$txtUserName.Text = $Env:USERNAME

$listView = [System.Windows.Controls.ListView]($content.FindName('listView1'))

$btnProcesses = [System.Windows.Controls.Button]($content.FindName('btnProcesses'))
$btnProcesses.Add_Click({
    $processes = Invoke-Command -ComputerName ($txtComputerName.Text -split ",") -ScriptBlock { Get-Process }
    $listView.View = New-GridView -Columns "Id","Name","PSComputerName"
    $listView.ItemsSource = $processes
})

$btnServices = [System.Windows.Controls.Button]($content.FindName('btnServices'))
$btnServices.Add_Click({
    $services = Invoke-Command -ComputerName ($txtComputerName.Text -split ",") -ScriptBlock { Get-Service }
    $listView.View = New-GridView -Columns "Status","Name","DisplayName","PSComputerName"
    $listView.ItemsSource = $services
})

$btnSearch = [System.Windows.Controls.Button]($content.FindName('btnSearch'))
$btnSearch.Add_Click({
    $searchCriteria = $txtUserName.Text
    $props = @{
        Properties = "*"
        ResultSetSize = 100
    }
    if ($searchCriteria -like "*.*") {
        $props["Filter"] = [scriptblock]::Create("Enabled -eq '$($true)' -and SamAccountName -like '$($searchCriteria)'")
    } else {
        $props["Filter"] = [scriptblock]::Create("Enabled -eq '$($true)' -and (Surname -like '$($searchCriteria)' -or GivenName -like '$($searchCriteria)' -or samaccountname -like '$($searchCriteria)')")
    }
    $users = Get-ADUser @props | Sort-Object -Property Surname,GivenName
    $listView.View = New-GridView -Columns "DisplayName","GivenName","SurName","MiddleName","SamAccountName","Description","Office","Title","Manager","EmployeeID","EmailAddress","OfficePhone","HomeDirectory", "WhenChanged", "WhenCreated"
    $listView.ItemsSource = @($users)
})

$window.ShowDialog() | Out-Null
