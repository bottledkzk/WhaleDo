param([string]$Gradle='gradle',[string]$JavaHome=$env:JAVA_HOME,[string]$AndroidSdk=$env:ANDROID_HOME,[ValidateSet('Debug','Release','Verification')][string]$Variant='Debug',[switch]$TestApk)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $AndroidSdk)) { throw 'Set ANDROID_HOME or -AndroidSdk to the official Android SDK.' }
$taskRoot=$PSScriptRoot
$cacheRoot=Join-Path $taskRoot '.local-build'
$original=@{}
foreach($name in @('JAVA_HOME','ANDROID_HOME','ANDROID_USER_HOME','GRADLE_USER_HOME')) {$original[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
  $env:JAVA_HOME=$JavaHome; $env:ANDROID_HOME=$AndroidSdk
  $env:ANDROID_USER_HOME=Join-Path $cacheRoot 'android-user'; $env:GRADLE_USER_HOME=Join-Path $cacheRoot 'gradle'
  $tasks=@("assemble"+$Variant)
  if($TestApk){$tasks+= @('assembleVerification','assembleVerificationAndroidTest')}
  & $Gradle -p $taskRoot $tasks --no-daemon --console=plain
  if($LASTEXITCODE -ne 0){throw 'Android course build failed.'}
} finally {foreach($name in $original.Keys){[Environment]::SetEnvironmentVariable($name,$original[$name],'Process')}}
