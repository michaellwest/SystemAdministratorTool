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

function Get-Button {
    param($Content, $Name)

    [System.Windows.Controls.Button]($Content.FindName($Name))
}

function Get-TextBox {
    param($Content, $Name)

    [System.Windows.Controls.TextBox]($Content.FindName($Name))
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

$txtComputerName = Get-TextBox $content 'txtComputerName'
$txtComputerName.Text = $Env:COMPUTERNAME
$txtUserName = Get-TextBox $content 'txtUserName'
$txtUserName.Text = $Env:USERNAME

$listView = [System.Windows.Controls.ListView]($content.FindName('listView1'))

$btnSearchComputer = Get-Button $content 'btnSearchComputer'
$btnSearchComputer.Add_Click({
    $details = ($txtComputerName.Text -split ",") | Get-ADComputer -Properties DNSHostName,OperatingSystem,OperatingSystemVersion,WhenCreated
    $listView.View = New-GridView -Columns "DNSHostName","OperatingSystem","OperatingSystemVersion","WhenCreated"
    $listView.ItemsSource = @($details)
})

$btnAdmin = Get-Button $content 'btnAdmin'
$btnAdmin.Add_Click({
    $admins = Get-CimInstance -ComputerName ($txtComputerName.Text -split ",") -ClassName Win32_Group -Filter "Name = 'Administrators'" | Get-CimAssociatedInstance -Association win32_groupuser
    $listView.View = New-GridView -Columns "Name","Domain","Description","PSComputerName"
    $listView.ItemsSource = ($admins)
})

$btnProcess = Get-Button $content 'btnProcess'
$btnProcess.Add_Click({
    $processes = Invoke-Command -ComputerName ($txtComputerName.Text -split ",") -ScriptBlock { Get-Process }
    $listView.View = New-GridView -Columns "Id","Name","PSComputerName"
    $listView.ItemsSource = $processes
})

$btnService = Get-Button $content 'btnService'
$btnService.Add_Click({
    $services = Invoke-Command -ComputerName ($txtComputerName.Text -split ",") -ScriptBlock { Get-Service }
    $listView.View = New-GridView -Columns "Status","Name","DisplayName","PSComputerName"
    $listView.ItemsSource = $services
})

$btnSearch = Get-Button $content 'btnSearch'
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
