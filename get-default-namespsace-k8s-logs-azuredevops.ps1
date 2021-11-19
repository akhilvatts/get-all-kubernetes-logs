$root_OutputDir="$(Build.SourcesDirectory)"
$date=Get-Date
$date = $date.ToString("yyyy-MM-dd")
$output_Namespace_Directory="pod_logs_$(kubectl config current-context)_$date"
$output_Directory="${root_OutputDir}/${output_Namespace_Directory}"
if (Test-Path -Path $output_Directory) {
Remove-Item $output_Directory -recurse -force
}
$describe_Directory= "${output_Directory}/describe"
$podlogs_Directory= "${output_Directory}/podlogs"
$eventlogs_Directory= "${output_Directory}/eventlogs"
$extension="log"
echo "Using output dir $output_Directory"
mkdir "$output_Directory"
mkdir "$describe_Directory"
mkdir "$podlogs_Directory"
mkdir "$eventlogs_Directory"

[pscustomobject]$hashtable = kubectl get po -A --no-headers
$hashtable | ForEach-Object {
$count = 0
$_.ToString().Split(" ") | foreach {
$Value1 = $_
if ($Value1 -ne "") {
    $count = $count + 1
    if ($count -eq 1) {
    # Set custom namespace
        $namespace=$value1
    }
    if ($count -eq 2) {
        $podname=$value1
    }
}
}
if ($namespace -eq 'default') {
Write-Host $namespace "contains" $podname
$filename = "${describe_Directory}/${namespace}.${podname}.describe"
kubectl describe pod -n "$namespace" "$podname" > "$filename"
foreach($container in (kubectl get po -n "$namespace" "$podname" -o jsonpath="{.spec.containers[*].name}")) {
    $filename_Prefix="$podlogs_Directory"+"/"+"$namespace"+"."+"$podname"+"."+"$container"
    $filename = $filename_Prefix + ".current." + $extension
    kubectl logs -n "$namespace" "$podname" "$container" > "$filename"
    echo "$filename"
    $filename = $filename_Prefix + ".previous." + $extension
    kubectl logs -p -n "$namespace" "$podname" "$container" > "$filename"
    echo "$filename"
    }
}
}
# Dump all events
$filename="$eventlogs_Directory/events.log"
kubectl get events -A > "$filename"

$archiveOutputPath = "$(Build.ArtifactStagingDirectory)" + "/" + "$output_Namespace_Directory" + ".zip"
Compress-Archive -Path $output_Directory -DestinationPath $archiveOutputPath