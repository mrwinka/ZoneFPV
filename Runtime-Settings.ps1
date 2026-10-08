function Get-ZoneFpvRuntimeSettings([string]$Text){
    $settings=@(
        @('General','DefaultExecuteInGameThreadMethod','EngineTick'),
        @('Hooks','HookEngineTick','1'),
        @('Hooks','HookUObjectProcessEvent','0')
    )
    foreach($setting in $settings){
        $section,$key,$value=$setting
        $pattern='(?m)^([ \t]*'+[regex]::Escape($key)+'[ \t]*=[ \t]*)[^\r\n]*'
        $matches=[regex]::Matches($Text,$pattern)
        if($matches.Count -gt 1){throw ('Duplicate runtime setting: '+$key)}
        if($matches.Count){
            $Text=[regex]::Replace($Text,$pattern,{param($match)$match.Groups[1].Value+$value})
        }else{
            $sectionPattern='(?m)^\['+[regex]::Escape($section)+'\][ \t]*\r?$'
            if([regex]::IsMatch($Text,$sectionPattern)){
                $Text=[regex]::new($sectionPattern).Replace($Text,[System.Text.RegularExpressions.MatchEvaluator]{param($match)$match.Value+"`r`n"+$key+' = '+$value},1)
            }else{$Text+="`r`n["+$section+"]`r`n"+$key+' = '+$value+"`r`n"}
        }
    }
    return $Text
}
