param(
  [string]$LedgerPath = "data/image_sources.csv",
  [string]$FlowersCsvPath = "data/flowers.csv",
  [int]$StartId = 1,
  [int]$EndId = 200,
  [string]$OutputPath = "tmp_factcheck_id_image_1_200.csv",
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

$manualKeywords = @{
  1='rose';2='sunflower';3='cherry blossom';4='anemone';5='fig tree flower';6='baby breath';7='aster';8='gypsophila';9='clover';10='narcissus';
  11='miyakowasure aster';12='forget me not';13='carnation';14='gerbera';15='lavender';16='hydrangea';17='cosmos';18='platycodon balloon';19='marigold tagetes';20='dahlia';
  21='tulip';22='daffodil narcissus';23='lily';24='lily valley';25='camellia';26='peony';27='peony paeonia';28='chrysanthemum';29='plum blossom mume';30='peach blossom';
  31='wisteria';32='lotus';33='violet viola';34='cyclamen';35='sasanqua camellia';36='osmanthus olive';37='gentian';38='bellflower campanula';39='sweet pea';40='hibiscus';
  41='fritillaria';42='erythronium dogtooth';43='veronica persica';44='nemophila';45='lupine lupin';46='iris';47='dogwood';48='houttuynia chameleon';49='trumpet';50='patrinia';
  51='spider lily';52='celosia';53='salvia';54='phalaenopsis orchid';55='oncidium orchid';56='dendrobium orchid';57='cymbidium orchid';58='primrose';59='feverfew matricaria';60='stock matthiola';
  61='campanula';62='petunia';63='vinca';64='impatiens';65='begonia';66='clematis';67='blue star tweedia';68='alstroemeria';69='lisianthus';70='echinacea';
  71='zinnia';72='poppy';73='freesia';74='muscari';75='hyacinth';76='crocus';77='snowdrop';78='hellebore';79='heliotrope';80='mirabilis';
  81='pansy';82='viola';83='geranium';84='calla lily';85='iris';86='jasmine';87='gardenia';88='lilac';89='statice';90='agapanthus';
  91='lobelia';92='nerine guernsey lily amaryllis';93='saffron crocus';94='amaryllis';95='gloriosa';96='chamomile';97='dayflower commelina';98='chinese lantern physalis';99='columbine aquilegia';100='delphinium';
  101='ranunculus';102='strelitzia bird paradise';103='calendula';104='bougainvillea';105='allium';
  106='erigeron';107='edelweiss';108='sandersonia';109='lysimachia';110='witch hazel hamamelis';
  111='wintersweet chimonanthus';112='oxalis';113='eranthis';114='spirea';115='dianthus';
  116='kalanchoe';117='nigella';118='hemerocallis daylily';119='gladiolus';120='verbena';
  121='eryngium';122='astilbe';123='pentas';124='cuphea';125='phlox subulata';
  126='adonis amurensis';127='mimosa acacia';128='salvia';129='colchicum';130='erigeron annuus';
  131='miniature rose';132='magnolia';133='rugosa rose';134='canna';135='monarda bergamot';
  136='rudbeckia';137='ixora';138='saxifrage';139='marguerite daisy';140='bacopa';
  141='snapdragon antirrhinum';142='cornflower cyanus';143='osteospermum';144='helichrysum';145='gazania';
  146='pelargonium';147='alyssum';148='hydrangea';149='monarda';150='sulfur cosmos';
  151='passionflower passiflora';152='zephyranthes';153='bletilla striata';154='brunfelsia';155='euphorbia';
  156='asclepias milkweed';157='phlox';158='echinops';159='ajuga';160='lagurus';
  161='actinotus flannel';162='matricaria feverfew';163='hypericum';164='dusty miller cineraria';165='celosia';
  166='vanda orchid';167='leucadendron';168='waxflower chamelaucium';169='chocolate cosmos';170='silene';
  171='potentilla';172='iberis candytuft';173='anemone sylvestris';174='trollius';175='heuchera';
  176='armeria thrift';177='lychnis';178='calceolaria';179='scabiosa';180='nierenbergia';
  181='exacum';182='lewisia';183='calibrachoa';184='nemesia';185='diascia';
  186='lantana';187='felicia';188='brachycome';189='melampodium';190='heliopsis';
  191='gaura';192='anigozanthos';193='grevillea';194='protea';195='anthurium';
  196='guzmania';197='cattleya orchid';198='sedum';199='ornithogalum';200='craspedia'
}

# For direct CDN links (images.pexels.com), we require reviewed photo IDs.
$approvedCdnPhotoIdByFlowerId = @{
  5 = 36781747
  11 = 5519492
  42 = 11968631
  92 = 16404015
  108 = 35569222
  113 = 35461880
  118 = 33825689
  129 = 35657115
  153 = 33692740
  159 = 36984070
  160 = 8809775
  161 = 35153783
  162 = 14081737
  172 = 36164798
  174 = 33735167
  177 = 17331371
  180 = 1188743
  181 = 4841305
  185 = 13104313
  187 = 17079444
  188 = 13347336
  192 = 32674039
}

if (-not [System.IO.Path]::IsPathRooted($LedgerPath)) {
  $LedgerPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $LedgerPath))
}

if (-not [System.IO.Path]::IsPathRooted($FlowersCsvPath)) {
  $FlowersCsvPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $FlowersCsvPath))
}

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputPath))
}

if (-not (Test-Path -LiteralPath $LedgerPath)) {
  throw "Ledger not found: $LedgerPath"
}

$flowersById = @{}
if (Test-Path -LiteralPath $FlowersCsvPath) {
  $flowerRows = @(Import-Csv -LiteralPath $FlowersCsvPath -Encoding UTF8)
  foreach ($f in $flowerRows) {
    $id = [int]$f.id
    $flowersById[$id] = $f
  }
}

$blacklistTokens = @(
  "class room", "classroom", "school", "wedding", "bride", "groom",
  "dog", "cat", "elephant", "cow", "cows", "car", "woman", "man", "people",
  "person", "city", "camera", "concert", "kangaroo", "kitten", "makeup",
  "chocolate", "stethoscope", "mask", "skyline", "corridor", "bikini"
)

$rows = @(
  Import-Csv -LiteralPath $LedgerPath -Encoding UTF8 |
    Where-Object { [int]$_.flower_id -ge $StartId -and [int]$_.flower_id -le $EndId } |
    Sort-Object { [int]$_.flower_id }
)

$result = foreach ($r in $rows) {
  $id = [int]$r.flower_id
  $url = [string]$r.source_url
  $slug = ""
  $photoIdFromCdn = $null

  if ($url.ToLowerInvariant() -match '/photo/([^/?#]+)') {
    $slug = ($Matches[1] -replace '[^a-z0-9]+', ' ').Trim()
  } elseif ($url.ToLowerInvariant() -match 'images\.pexels\.com/photos/(\d+)/pexels-photo-\d+\.(jpeg|jpg|png)') {
    $photoIdFromCdn = [int]$Matches[1]
    $slug = "(image-cdn-no-slug)"
  }

  $tokens = @()
  if ($manualKeywords.ContainsKey($id)) {
    $tokens = @($manualKeywords[$id] -split '\s+' | Where-Object { $_ -and $_.Length -ge 3 })
  }

  $hits = 0
  foreach ($t in $tokens) {
    if ($slug.Contains($t)) { $hits++ }
  }

  $factsTokens = @()
  if ($flowersById.ContainsKey($id)) {
    $factsKeys = [string]$flowersById[$id].factsKeys
    if (-not [string]::IsNullOrWhiteSpace($factsKeys)) {
      $factsTokens = @(
        $factsKeys -split '\|' |
          ForEach-Object { $_.Trim().ToLowerInvariant() } |
          Where-Object { $_ -match '[a-z]' } |
          ForEach-Object { ($_ -replace '[^a-z0-9\s-]', ' ').Trim() } |
          Where-Object { $_ -ne '' }
      )
    }
  }

  $factsHits = 0
  foreach ($ft in $factsTokens) {
    foreach ($part in ($ft -split '\s+' | Where-Object { $_.Length -ge 3 })) {
      if ($slug.Contains($part)) {
        $factsHits++
        break
      }
    }
  }

  $status = "PASS"
  $reason = "No issue found by automatic check"

  if ([string]::IsNullOrWhiteSpace($url)) {
    $status = "FAIL:no_source"
    $reason = "source_url is empty"
  } elseif ($slug -eq "(image-cdn-no-slug)") {
    if ($approvedCdnPhotoIdByFlowerId.ContainsKey($id) -and $approvedCdnPhotoIdByFlowerId[$id] -eq $photoIdFromCdn) {
      $status = "PASS:reviewed_cdn_id"
      $reason = "CDN photo ID matches reviewed mapping"
    } else {
      $status = "FAIL:cdn_photo_id_not_reviewed"
      $reason = "CDN direct link requires reviewed photo ID match"
    }
  } elseif ($hits -lt 1 -and $factsHits -lt 1) {
    $status = "FAIL:name_slug_mismatch"
    $reason = "No name/facts keyword hit in source URL slug"
  } else {
    $lowerSlug = $slug.ToLowerInvariant()
    $flowerCueRegex = '(flower|flowers|bloom|blossom|lily|rose|orchid|tulip|daisy|aster|petunia|chrysanthemum|hydrangea|lotus|iris|camellia|lavender|bouquet|plant)'
    $hasFlowerCue = ($hits -gt 0) -or ($factsHits -gt 0) -or ($lowerSlug -match $flowerCueRegex)
    $bad = $blacklistTokens | Where-Object {
      $token = $_.ToLowerInvariant()
      $lowerSlug -match ("(^| )" + [Regex]::Escape($token) + "( |$)")
    } | Select-Object -First 1

    if ($bad -and -not $hasFlowerCue) {
      $status = "FAIL:slug_blacklist"
      $reason = ("Unexpected non-flower keyword in slug: {0}" -f $bad)
    } elseif ($factsTokens.Count -gt 0 -and $factsHits -lt 1) {
      $status = "WARN:facts_key_no_hit"
      $reason = "No factsKeys token hit in source URL slug"
    } elseif ($id -gt 100 -and $tokens.Count -eq 0 -and $factsTokens.Count -eq 0) {
      $status = "PASS:non_strict"
      $reason = "Passed by source/file policy (non-strict semantic check)"
    }
  }

  $filePath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $r.file))
  if (-not (Test-Path -LiteralPath $filePath)) {
    $status = "FAIL:file_missing"
    $reason = ("Image file not found: {0}" -f $r.file)
  }

  [PSCustomObject]@{
    id = $id
    name = $r.flower_name
    status = $status
    hits = $hits
    slug = $slug
    photo_id = $photoIdFromCdn
    reason = $reason
    url = $url
    file = $r.file
  }
}

$pass = @($result | Where-Object { $_.status -like "PASS*" }).Count
$fail = @($result | Where-Object { $_.status -like "FAIL*" }).Count

$reportSaved = $false
try {
  $result | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutputPath -Force
  $reportSaved = $true
} catch {
  $reportSaved = $false
}

if (-not $Quiet) {
  Write-Host ("id-image factcheck: pass={0} fail={1}" -f $pass, $fail)
  if ($fail -gt 0) {
    $result | Where-Object { $_.status -like "FAIL*" } |
      Format-Table -AutoSize | Out-String -Width 260 | Write-Host
  }
  if ($reportSaved) {
    Write-Host ("report: {0}" -f $OutputPath)
  } else {
    Write-Host ("report: skipped (could not write {0})" -f $OutputPath)
  }
}

if ($fail -gt 0) {
  exit 1
}

exit 0
