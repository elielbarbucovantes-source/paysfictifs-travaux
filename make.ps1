####### The starting point for the script is the bottom #######

# Use TLS 1.2 (and 1.3 where available) for engine and GeoIP downloads.
try
{
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
}
catch
{
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# The engine targets net6.0: let it run on an installed .NET 8 runtime.
$env:DOTNET_ROLL_FORWARD = "LatestMajor"
$script:CommandExit = 0

###############################################################
########################## FUNCTIONS ##########################
###############################################################
function All-Command
{
	If (!(Test-Path "*.sln"))
	{
		Write-Host "No custom solution file found. Aborting." -ForegroundColor Red
		$script:CommandExit = 1
		return
	}

	if ((CheckForDotnet) -eq 1)
	{
		$script:CommandExit = 1
		return
	}

	Write-Host "Building $modID in" $configuration "configuration..." -ForegroundColor Cyan
	dotnet build -c $configuration --nologo -p:TargetPlatform=win-x64
	$buildExit = $LASTEXITCODE

	if ($buildExit -ne 0)
	{
		Write-Host "Build failed. If just the development tools failed to build, try installing Visual Studio. You may also still be able to run the game." -ForegroundColor Red
	}
	else
	{
		Write-Host "Build succeeded." -ForegroundColor Green
	}

	$script:CommandExit = $buildExit
}

function Clean-Command
{
	If (!(Test-Path "*.sln"))
	{
		Write-Host "No custom solution file found - nothing to clean. Aborting." -ForegroundColor Red
		$script:CommandExit = 1
		return
	}

	if ((CheckForDotnet) -eq 1)
	{
		$script:CommandExit = 1
		return
	}

	Write-Host "Cleaning $modID..." -ForegroundColor Cyan

	dotnet clean /nologo
	$cleanExit = $LASTEXITCODE
	Remove-Item -Path ./*/obj -Recurse -Force -ErrorAction Ignore
	Remove-Item -Path "$env:ENGINE_DIRECTORY/bin" -Recurse -Force -ErrorAction Ignore
	Remove-Item -Path "$env:ENGINE_DIRECTORY/*/obj" -Recurse -Force -ErrorAction Ignore

	Write-Host "Clean complete." -ForegroundColor Green
	$script:CommandExit = $cleanExit
}

function Version-Command
{
	if ($command.Length -gt 1)
	{
		$version = $command[1]
	}
	elseif (Get-Command 'git' -ErrorAction SilentlyContinue)
	{
		$gitRepo = git rev-parse --is-inside-work-tree
		if ($gitRepo)
		{
			$version = git name-rev --name-only --tags --no-undefined HEAD 2>$null
			if ($version -eq $null)
			{
				$version = "git-" + (git rev-parse --short HEAD)
			}
		}
		else
		{
			Write-Host "Not a git repository. The version will remain unchanged." -ForegroundColor Red
		}
	}
	else
	{
		Write-Host "Unable to locate Git. The version will remain unchanged." -ForegroundColor Red
	}

	if ($version -ne $null)
	{
		$mod = "mods/" + $modID + "/mod.yaml"
		$replacement = (Get-Content $mod) -Replace "Version:.*", ("Version: {0}" -f $version)
		Set-Content $mod $replacement

		$prefix = $(Get-Content $mod) | Where { $_.ToString().EndsWith(": User") }
		if ($prefix -and $prefix.LastIndexOf("/") -ne -1)
		{
			$prefix = $prefix.Substring(0, $prefix.LastIndexOf("/"))
		}
		$replacement = (Get-Content $mod) -Replace ".*: User", ("{0}/{1}: User" -f $prefix, $version)
		Set-Content $mod $replacement

		Write-Host ("Version strings set to '{0}'." -f $version)
	}
}

function Test-Command
{
	if ((CheckForUtility) -eq 1)
	{
		$script:CommandExit = 1
		return
	}

	Write-Host "Testing $modID mod MiniYAML..." -ForegroundColor Cyan
	InvokeCommand "$utilityPath $modID --check-yaml"
}

function Check-Command
{
	If (!(Test-Path "*.sln"))
	{
		Write-Host "No custom solution file found. Skipping static code checks." -ForegroundColor Cyan
		return
	}

	Write-Host "Compiling $modID in Debug configuration..." -ForegroundColor Cyan

	dotnet clean -c Debug --nologo --verbosity minimal
	dotnet build -c Debug --nologo -warnaserror -p:TargetPlatform=win-x64

	if ($LASTEXITCODE -ne 0)
	{
		Write-Host "Build failed." -ForegroundColor Red
		$script:CommandExit = 1
		return
	}

	if ((CheckForUtility) -eq 0)
	{
		Write-Host "Checking $modID for explicit interface violations..." -ForegroundColor Cyan
		InvokeCommand "$utilityPath $modID --check-explicit-interfaces"

		Write-Host "Checking $modID for incorrect conditional trait interface overrides..." -ForegroundColor Cyan
		InvokeCommand "$utilityPath $modID --check-conditional-trait-interface-overrides"
	}
}

function Check-Scripts-Command
{
	if ((Get-Command "luac.exe" -ErrorAction SilentlyContinue) -ne $null)
	{
		Write-Host "Testing Lua scripts..." -ForegroundColor Cyan
		foreach ($script in Get-ChildItem "mods/*/maps/*/*.lua")
		{
			luac -p $script
		}
		Write-Host "Check completed!" -ForegroundColor Green
	}
	else
	{
		Write-Host "luac.exe could not be found. Please install Lua." -ForegroundColor Red
		$script:CommandExit = 1
	}
}

function CheckForUtility
{
	if (Test-Path $utilityPath)
	{
		return 0
	}

	Write-Host "OpenRA.Utility.exe could not be found. Build the project first using the `"all`" command." -ForegroundColor Red
	return 1
}

function CheckForDotnet
{
	if ((Get-Command "dotnet" -ErrorAction SilentlyContinue) -eq $null)
	{
		Write-Host "The 'dotnet' tool is required to compile OpenRA. Install the .NET 8 SDK (6 is also accepted): https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Red
		return 1
	}

	$sdks = @(dotnet --list-sdks 2>$null)
	$has6 = $False
	$has8 = $False
	foreach ($line in $sdks)
	{
		if ($line -match '^\s*(\d+)\.')
		{
			$major = $Matches[1]
			if ($major -eq "8") { $has8 = $True }
			if ($major -eq "6") { $has6 = $True }
		}
	}

	if ($has8)
	{
		$env:DOTNET_ROLL_FORWARD = "LatestMajor"
		return 0
	}

	if ($has6)
	{
		$env:DOTNET_ROLL_FORWARD = "LatestMajor"
		Write-Host "Warning: only the .NET 6 SDK was found. .NET 8 SDK is recommended for this mod: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
		return 0
	}

	Write-Host "No supported .NET SDK found (6 or 8 required). Install the .NET 8 SDK: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Red
	return 1
}

function WaitForInput
{
	$redirected = $False
	try { $redirected = [Console]::IsInputRedirected } catch { }
	if (-not [Environment]::UserInteractive -or $redirected)
	{
		return
	}

	Write-Host "Press enter to continue."
	while ($true)
	{
		if ([System.Console]::KeyAvailable)
		{
			return
		}
		Start-Sleep -Milliseconds 50
	}
}

function ReadConfigLine($line, $name)
{
	if ($line.TrimStart().StartsWith("#"))
	{
		return
	}

	$prefix = $name + '='
	if ($line.StartsWith($prefix))
	{
		[Environment]::SetEnvironmentVariable($name, $line.Replace($prefix, '').Replace('"', ''))
	}
}

function ParseConfigFile($fileName)
{
	$names = @("MOD_ID", "ENGINE_VERSION", "AUTOMATIC_ENGINE_MANAGEMENT", "AUTOMATIC_ENGINE_SOURCE",
		"AUTOMATIC_ENGINE_EXTRACT_DIRECTORY", "AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME", "ENGINE_DIRECTORY")

	$reader = [System.IO.File]::OpenText($fileName)
	while($null -ne ($line = $reader.ReadLine()))
	{
		foreach ($name in $names)
		{
			ReadConfigLine $line $name
		}
	}
	$reader.Close()

	$missing = @()
	foreach ($name in $names)
	{
		if (!([System.Environment]::GetEnvironmentVariable($name)))
		{
			$missing += $name
		}
	}

	if ($missing)
	{
		Write-Host "Required mod.config variables are missing:"
		foreach ($m in $missing)
		{
			Write-Host "   $m"
		}
		Write-Host "Repair your mod.config (or user.config) and try again."
		WaitForInput
		exit 1
	}
}

function InvokeCommand
{
	param($expression)
	# $? is the return value of the called expression
	# Invoke-Expression itself will always succeed, even if the invoked expression fails
	# So temporarily store the return value in $success
	$expression += '; $success = $?'
	Invoke-Expression $expression
	if ($success -eq $False)
	{
		exit 1
	}
}

###############################################################
############################ Main #############################
###############################################################
if ($PSVersionTable.PSVersion.Major -clt 3)
{
    Write-Host "The makefile requires PowerShell version 3 or higher." -ForegroundColor Red
    Write-Host "Please download and install the latest Windows Management Framework version from Microsoft." -ForegroundColor Red
    WaitForInput
    exit 1
}

if ($args.Length -eq 0)
{
	Write-Host "Command list:"
	Write-Host ""
	Write-Host "  all             Builds the game, its development tools and the mod dlls."
	Write-Host "  version         Sets the version strings for all mods to the latest"
	Write-Host "                  version for the current Git branch."
	Write-Host "  clean           Removes all built and copied files."
	Write-Host "                  from the mods and the engine directories."
	Write-Host "  test            Tests the mod's MiniYAML for errors."
	Write-Host "  check           Checks .cs files for StyleCop violations."
	Write-Host "  check-scripts   Checks .lua files for syntax errors."
	Write-Host ""
	$redirected = $False
	try { $redirected = [Console]::IsInputRedirected } catch { }
	if (-not [Environment]::UserInteractive -or $redirected)
	{
		Write-Host "No command was supplied and console input is not available. Use 'make.cmd all'." -ForegroundColor Red
		exit 1
	}
	$command = (Read-Host "Enter command").Split(' ', 2)
}
else
{
	$command = $args
}

# Set the working directory for our IO methods
$templateDir = $pwd.Path
[System.IO.Directory]::SetCurrentDirectory($templateDir)

# Load the environment variables from the config file and get the mod ID.
ParseConfigFile "mod.config"

if (Test-Path "user.config")
{
	ParseConfigFile "user.config"
}

$modID = $env:MOD_ID

$env:MOD_SEARCH_PATHS = "./mods,$env:ENGINE_DIRECTORY/mods"
$env:ENGINE_DIR = ".." # May be used by the Utility; different from ENGINE_DIRECTORY, which is for this script.

function Resolve-ConfigPath($path)
{
	if ([System.IO.Path]::IsPathRooted($path))
	{
		return [System.IO.Path]::GetFullPath($path)
	}

	return [System.IO.Path]::GetFullPath((Join-Path $templateDir $path))
}

# Fetch and/or build the engine if required.
if ($command -eq "all" -or $command -eq "clean" -or $command -eq "check")
{
	$enginePath = Resolve-ConfigPath $env:ENGINE_DIRECTORY
	$versionFile = Join-Path $enginePath "VERSION"
	$currentEngine = ""
	if (Test-Path -LiteralPath $versionFile)
	{
		$reader = [System.IO.File]::OpenText($versionFile)
		$currentEngine = $reader.ReadLine()
		$reader.Close()
		if ($null -ne $currentEngine) { $currentEngine = $currentEngine.Trim() }
	}

	if ($currentEngine -ne "" -and $currentEngine -eq $env:ENGINE_VERSION)
	{
		Push-Location -LiteralPath $enginePath
		try
		{
			& ".\make.cmd" $command
			$engineExit = $LASTEXITCODE
		}
		finally
		{
			Pop-Location
		}

		if ($engineExit -ne 0)
		{
			Write-Host "Engine build failed with exit code $engineExit. Aborting." -ForegroundColor Red
			exit $engineExit
		}
		Write-Host ""
	}
	elseif ($env:AUTOMATIC_ENGINE_MANAGEMENT -ne "True")
	{
		Write-Host "Automatic engine management is disabled."
		Write-Host "Please manually update the engine to version $env:ENGINE_VERSION."
		WaitForInput
		exit 1
	}
	else
	{
		Write-Host "OpenRA engine version $env:ENGINE_VERSION is required."

		if (Test-Path -LiteralPath $enginePath)
		{
			if ($currentEngine -ne "")
			{
				Write-Host "Deleting engine version $currentEngine."
			}
			else
			{
				Write-Host "Deleting existing engine (unknown version)."
			}
			Remove-Item -LiteralPath $enginePath -Recurse -Force
		}

		Write-Host "Downloading engine..."

		$extractDir = Resolve-ConfigPath $env:AUTOMATIC_ENGINE_EXTRACT_DIRECTORY
		if (Test-Path -LiteralPath $extractDir)
		{
			Remove-Item -LiteralPath $extractDir -Recurse -Force
		}
		New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

		$url = $env:AUTOMATIC_ENGINE_SOURCE
		$url = $url.Replace("$", "").Replace("{ENGINE_VERSION}", $env:ENGINE_VERSION)
		$dlPath = Join-Path $extractDir $env:AUTOMATIC_ENGINE_TEMP_ARCHIVE_NAME

		$client = New-Object System.Net.WebClient
		try
		{
			$client.DownloadFile($url, $dlPath)
		}
		finally
		{
			$client.Dispose()
		}

		try { Add-Type -AssemblyName "System.IO.Compression.FileSystem" } catch { Add-Type -AssemblyName "System.IO.Compression.ZipFile" }
		[System.IO.Compression.ZipFile]::ExtractToDirectory($dlPath, $extractDir)
		Remove-Item -LiteralPath $dlPath -Force

		# GitHub source archives hold the checkout in one top-level directory.
		$topLevelDirs = @(Get-ChildItem -LiteralPath $extractDir -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "OpenRA.sln") })
		if ($topLevelDirs.Count -ne 1)
		{
			Write-Host "Unexpected engine archive layout: expected 1 directory containing OpenRA.sln, found $($topLevelDirs.Count)." -ForegroundColor Red
			exit 1
		}

		Move-Item -LiteralPath $topLevelDirs[0].FullName -Destination $enginePath -Force
		Remove-Item -LiteralPath $extractDir -Recurse -Force

		if (!(Test-Path -LiteralPath (Join-Path $enginePath "OpenRA.sln")))
		{
			Write-Host "Downloaded engine is not the expected OpenRA checkout (OpenRA.sln missing)." -ForegroundColor Red
			exit 1
		}

		Push-Location -LiteralPath $enginePath
		try
		{
			& ".\make.cmd" "version" $env:ENGINE_VERSION
			$versionExit = $LASTEXITCODE
			if ($versionExit -ne 0)
			{
				Write-Host "Engine version stamping failed with exit code $versionExit. Aborting." -ForegroundColor Red
				exit $versionExit
			}

			$downloadedVersion = ""
			$newVersionFile = Join-Path $enginePath "VERSION"
			if (Test-Path -LiteralPath $newVersionFile)
			{
				$reader = [System.IO.File]::OpenText($newVersionFile)
				$downloadedVersion = $reader.ReadLine()
				$reader.Close()
				if ($null -ne $downloadedVersion) { $downloadedVersion = $downloadedVersion.Trim() }
			}

			if ($downloadedVersion -ne $env:ENGINE_VERSION)
			{
				Write-Host "Downloaded engine version stamp mismatch (expected $($env:ENGINE_VERSION), got $downloadedVersion)." -ForegroundColor Red
				exit 1
			}

			& ".\make.cmd" $command
			$engineExit = $LASTEXITCODE
		}
		finally
		{
			Pop-Location
		}

		if ($engineExit -ne 0)
		{
			Write-Host "Engine build failed with exit code $engineExit. Aborting." -ForegroundColor Red
			exit $engineExit
		}
		Write-Host ""
	}
}

$utilityPath = $env:ENGINE_DIRECTORY + "/bin/OpenRA.Utility.exe"

$configuration = "Release"
if ($args.Contains("CONFIGURATION=Debug"))
{
	$configuration = "Debug"
}

$execute = $command
if ($command.Length -gt 1)
{
	$execute = $command[0]
}

switch ($execute)
{
	"all" { All-Command }
	"version" { Version-Command }
	"clean" { Clean-Command }
	"test" { Test-Command }
	"check" { Check-Command }
	"check-scripts" { Check-Scripts-Command }
	Default { Write-Host ("Invalid command '{0}'" -f $command); $script:CommandExit = 1 }
}

# In case the script was called without any parameters we keep the window open
if ($args.Length -eq 0)
{
	WaitForInput
}

exit $script:CommandExit
