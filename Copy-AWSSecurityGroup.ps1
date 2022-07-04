<#
    .SYNOPSIS

	Copies AWS security group accross the regions

    .Description

	Copies AWS security group accross the regions

    .NOTES

    © Evgeny Barannikov, TenenGroup
	
    .PARAMETER SourceGroupId

	Source security group ID

	.PARAMETER SourceRegion

	Optional parameter. If omitted the default region is used

	.PARAMETER TargetRegion

	Destination region for the security group to be copied to

	.PARAMETER TargetVpc

	Mandatory parameter. VPC for the security group to reside

	.PARAMETER TargetPrefixListId

	If PrefixList is used for the source it should be pre-created and indicated here

    .EXAMPLE

	Copy-AWSSecurityGroup.ps1 -SourceGroupId sg-0e13dfa5b5bdecd38 -TargetRegion ap-southeast-2 -TargetVpc vpc-01c5af66 -TargetPrefixListId pl-03241911caf8200ca -SourceRegion eu-west-1

    .LINK
#>

param(
	[Parameter (Mandatory = $true, Position = 0)]
	[string]$SourceGroupId,
	[Parameter (Mandatory = $false, Position = 1)]
	[ValidateSet('eu-west-1','us-east-1','ap-southeast-2','eu-central-1')]
	[string]$SourceRegion,
	[Parameter (Mandatory = $true, Position = 2)]
	[ValidateSet('eu-west-1','us-east-1','ap-southeast-2','eu-central-1')]
	[string]$TargetRegion,
	[Parameter (Mandatory = $true, Position = 3)]
	[string]$TargetVpc,
	[Parameter (Mandatory = $false, Position = 4)]
	[string]$TargetPrefixListId
)

try {
	$Group =  Get-EC2SecurityGroup -GroupId $SourceGroupId -Region $SourceRegion
	[array[]]$Rules = $Group.IpPermissions
}
catch {
	$ErrorMessage = $_.Exception.Message
}
finally {
	if (([string]::IsNullOrEmpty($ErrorMessage)) -and (!([string]::IsNullOrEmpty($Group)))){
		Write-Host -ForegroundColor Gray "Copying " -NoNewLine
		Write-Host -ForegroundColor White $Group.GroupName -NoNewLine
		Write-Host -ForegroundColor Gray " to " -NoNewLine
		Write-Host -ForegroundColor White $TargetRegion.PadRight(58-($Group.GroupName.Length)) -NoNewLine
	}
	else {
		throw $ErrorMessage
		exit
	}
}

try {
	$NewGroup = New-EC2SecurityGroup -GroupName $Group.GroupName -Description $Group.Description -Region $TargetRegion -VpcId $TargetVpc
}
catch {
	$ErrorMessage = $_.Exception.Message
}
finally {
	if (([string]::IsNullOrEmpty($ErrorMessage)) -and (!([string]::IsNullOrEmpty($NewGroup)))){
		Write-Host -ForegroundColor Green "OK"
	}
	else {
		Write-Host -ForegroundColor Red "FAIL"
		throw $ErrorMessage
		exit
	}
}

if (!([string]::IsNullOrEmpty($Rules))){
	foreach ($Rule in $Rules){
		Write-Host -ForegroundColor DarkGray " Adding " -NoNewLine
		if ($TargetPrefixListId){
			$Rule.PrefixListIds.Id = $TargetPrefixListId
		}
		if ($Rule.PrefixListIds.Id){
			[string]$RuleDescription = $Rule.FromPort,$Rule.IpProtocol,$Rule.ToPort,$Rule.PrefixListIds.Id
			Write-Host -ForegroundColor DarkCyan $RuleDescription.PadRight(62) -NoNewLine
			try {
				$Action = Grant-EC2SecurityGroupIngress -GroupId $NewGroup -IpPermission @($Rule) -Region $TargetRegion
			}
			catch {
				$ErrorMessage = $_.Exception.Message
			}
			if ([string]::IsNullOrEmpty($ErrorMessage)){
				Write-Host -ForegroundColor Green "OK"
			}
			else {
				Write-Host -ForegroundColor Red "FAIL"
				Write-Error $ErrorMessage
				Clear-Variable ErrorMessage
			}
		}
		else {
			[string]$RuleDescription = $Rule.FromPort,$Rule.IpProtocol,$Rule.ToPort,($Rule.Ipv4Ranges.CidrIP.split(" ") -join ", ")
			Write-Host -ForegroundColor DarkCyan $RuleDescription.PadRight(62) -NoNewLine
			try {
				$Action = Grant-EC2SecurityGroupIngress -GroupId $NewGroup -IpPermission @($Rule) -Region $TargetRegion
			}
			catch {
				$ErrorMessage = $_.Exception.Message
			}
			if ([string]::IsNullOrEmpty($ErrorMessage)){
				Write-Host -ForegroundColor Green "OK"
			}
			else {
				Write-Host -ForegroundColor Red "FAIL"
				Write-Error $ErrorMessage
				Clear-Variable ErrorMessage
			}
		}
	}
}