Import-Module ActiveDirectory

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

[xml]$xaml = (Get-Content -Path (Join-Path (Split-Path -Path $script:MyInvocation.MyCommand.Path) "MainWindow.xaml"))
$reader = New-Object System.Xml.XmlNodeReader $xaml 
$window = [System.Windows.Markup.XamlReader]::Load($reader) 

$txtComputerName = [System.Windows.Controls.TextBox]($window.FindName('txtComputerName'))
$txtComputerName.Text = $Env:COMPUTERNAME
$txtUserName = [System.Windows.Controls.TextBox]($window.FindName('txtUserName'))
$txtUserName.Text = $Env:USERNAME

$listView = [System.Windows.Controls.ListView]($window.FindName('listView1'))

$btnProcesses = [System.Windows.Controls.Button]($window.FindName('btnProcesses'))
$btnProcesses.Add_Click({
    $processes = Get-Process -ComputerName $txtComputerName.Text
    $listView.View = New-GridView -Columns "Id","Name"
    $listView.ItemsSource = $processes
})

$btnServices = [System.Windows.Controls.Button]($window.FindName('btnServices'))
$btnServices.Add_Click({
    $services = Get-Service -ComputerName $txtComputerName.Text
    $listView.View = New-GridView -Columns "Status","Name","DisplayName"
    $listView.ItemsSource = $services
})

$btnSearch = [System.Windows.Controls.Button]($window.FindName('btnSearch'))
$btnSearch.Add_Click({
    $searchCriteria = $txtUserName.Text
    $props = @{
        Filter = { Enabled -eq $true }
        Properties = "*"
        ResultSetSize = 100
    }
    if ($searchCriteria -like "*.*") {
        $props["Filter"] = { Enabled -eq $true -and SamAccountName -like $searchCriteria }
    } else {
        $props["Filter"] = { Enabled -eq $true -and (Surname -like $searchCriteria -or GivenName -like $searchCriteria -or samaccountname -like $searchCriteria) }
    }
    $users = Get-ADUser @props | Sort-Object -Property Surname,GivenName
    $listView.View = New-GridView -Columns "DisplayName","GivenName","SurName","MiddleName","SamAccountName","Description","Office","Title","Manager","EmployeeID","EmailAddress","OfficePhone","HomeDirectory", "WhenChanged", "WhenCreated"
    $listView.ItemsSource = @($users)
})

$window.ShowDialog() | Out-Null
