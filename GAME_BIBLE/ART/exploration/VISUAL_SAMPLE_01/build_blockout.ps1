# Project Stride - Visual Sample Generation 01
# Deterministic grayscale composition blockout generator.
#
# EXPLORATION-SUPPORT ARTIFACT ONLY. This is not production rendering
# infrastructure, not part of the app build, and not referenced by any Flutter,
# Dart, Kotlin, Swift, or CI target. It exists so the composition control image
# stays reproducible and editable.
#
# The output is a CONTROL INPUT for image generation, not an art sample. It
# carries no art-direction information: no outline style, no pixel grid, no
# texture, no lighting, no head-to-body ratio, no typography. Grayscale values
# encode element identity and separation only, and no mass is a shadow.
#
# Coordinates and the value-to-element legend are documented in
# GAME_BIBLE/ART/VISUAL_SAMPLE_GENERATION_01.md, sections 5.3 and 5.4.
# Every value here is PROVISIONAL FOR VISUAL SAMPLE GENERATION 01 ONLY,
# including the 1024 x 1536 frame.
#
# No text is drawn into the image: burnt-in labels contaminate structural
# conditioning and can be transcribed into generated output. The legend lives
# in the markdown document instead.
#
# Dependencies: none beyond Windows PowerShell and System.Drawing.
#
# Usage, from the repository root:
#   powershell -File GAME_BIBLE/ART/exploration/VISUAL_SAMPLE_01/build_blockout.ps1
# Writes composition_blockout.png beside this script unless -OutPath is given.

param(
  [string]$OutPath = (Join-Path $PSScriptRoot 'composition_blockout.png')
)

Add-Type -AssemblyName System.Drawing

$W = 1024
$H = 1536

$bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

function New-Gray([int]$v) {
  return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($v, $v, $v))
}

function Fill-Rect([int]$v, [double]$x, [double]$y, [double]$w, [double]$h) {
  $b = New-Gray $v
  $g.FillRectangle($b, [single]$x, [single]$y, [single]$w, [single]$h)
  $b.Dispose()
}

function Fill-Ellipse([int]$v, [double]$cx, [double]$cy, [double]$rx, [double]$ry) {
  $b = New-Gray $v
  $g.FillEllipse($b, [single]($cx - $rx), [single]($cy - $ry), [single](2 * $rx), [single](2 * $ry))
  $b.Dispose()
}

function Fill-Poly([int]$v, [double[][]]$pts) {
  $b = New-Gray $v
  $arr = New-Object 'System.Drawing.PointF[]' $pts.Length
  for ($i = 0; $i -lt $pts.Length; $i++) {
    $arr[$i] = New-Object System.Drawing.PointF ([single]$pts[$i][0]), ([single]$pts[$i][1])
  }
  $g.FillPolygon($b, $arr)
  $b.Dispose()
}

# ---------------------------------------------------------------- 1. sky + ground
Fill-Rect 235 0 0 $W $H                      # sky
Fill-Rect 200 0 338 $W 1075                  # meadow ground plane, horizon at y=338

# ---------------------------------------------------------------- 2. distant treeline
Fill-Rect 170 0 318 $W 27
for ($x = 0; $x -lt 1030; $x += 34) { Fill-Ellipse 170 $x 320 21 18 }  # scalloped top = distant canopy

# ---------------------------------------------------------------- 3. two roads leaving frame
Fill-Poly 165 @( @(1024,398), @(1024,422), @(664,598), @(652,584) )   # east road, exits right edge
Fill-Poly 165 @( @(0,452), @(0,474), @(150,652), @(134,640) )         # west road, exits left edge

# ---------------------------------------------------------------- 4. settlement roofs
Fill-Poly 120 @( @(90,545), @(175,330), @(260,545) )
Fill-Poly 125 @( @(300,545), @(380,360), @(460,545) )
Fill-Poly 115 @( @(428,545), @(470,392), @(512,545) )

# ---------------------------------------------------------------- 5. one smoke plume
Fill-Poly 215 @( @(192,392), @(212,392), @(228,268), @(220,176), @(204,182), @(212,272) )

# ---------------------------------------------------------------- 6. trees flanking settlement
Fill-Ellipse 130 102 430 75 70
Fill-Rect     90  92 480 20 80
Fill-Ellipse 130 532 405 80 72
Fill-Rect     90 522 460 20 85

# ---------------------------------------------------------------- 7. palisade wall, posts, gate
Fill-Rect 100 51 545 461 105
for ($x = 51; $x -lt 512; $x += 32) { Fill-Rect 85 $x 522 14 30 }     # post tops
Fill-Rect 205 270 555 75 95                                            # open gate void
Fill-Rect  85 256 535 16 115                                           # gate post left
Fill-Rect  85 343 535 16 115                                           # gate post right
Fill-Rect  85 256 535 103 22                                           # gate lintel

# ---------------------------------------------------------------- 8. scrub along palisade base
Fill-Rect 175  51 620 204 34
Fill-Rect 175 360 620 152 34

# ---------------------------------------------------------------- 9. main path, gate -> frame bottom
Fill-Poly 165 @( @(280,668), @(335,668), @(515,952), @(670,1413), @(520,1413), @(415,952) )

# ---------------------------------------------------------------- 10. props
Fill-Rect  95 527 780 12 80                  # signpost post
Fill-Rect  95 539 790 61 16                  # signpost arm, east
Fill-Rect  95 470 812 57 16                  # signpost arm, west
Fill-Ellipse 110 205 790 36 9                # firewood log 1
Fill-Ellipse 110 205 806 36 9                # firewood log 2
Fill-Ellipse 110 205 822 36 9                # firewood log 3
Fill-Ellipse 140 512 1106 14 8               # path stone 1
Fill-Ellipse 140 563 1275 16 9               # path stone 2

# ---------------------------------------------------------------- 11. NPC, feet (369,706), height 154
Fill-Ellipse 70 372 566 13 14                # head, offset right = facing toward player
Fill-Poly    70 @( @(349,581), @(395,581), @(391,648), @(353,648) )   # torso
Fill-Rect    70 337 585 12 58                # arm, viewer-left
Fill-Rect    70 395 585 12 58                # arm, viewer-right
Fill-Rect    70 353 648 16 58                # leg
Fill-Rect    70 375 648 16 58                # leg

# ---------------------------------------------------------------- 12. player, feet (430,1106), height 261
Fill-Rect    55 383 895 18 52                # traveler pack, peeking viewer-left
Fill-Ellipse 40 438 866 21 22                # head, offset right = three-quarter front-right facing
Fill-Poly    40 @( @(391,890), @(469,890), @(461,995), @(399,995) )   # torso
Fill-Rect    40 379 892 15 93                # arm, viewer-left
Fill-Rect    40 466 892 15 93                # arm, viewer-right
Fill-Rect    40 402 995 23 111               # leg
Fill-Rect    40 435 995 23 111               # leg
Fill-Poly    55 @( @(466,972), @(478,978), @(486,1038), @(474,1040) ) # training sword at left hip

# ---------------------------------------------------------------- 13. Meadow Patch + Meadow Herb
Fill-Ellipse 60 676 1282 72 28                                        # tuft base mass
Fill-Poly 60 @( @(668,1292), @(684,1292), @(700,1196), @(690,1198) )  # blades fanning from one root
Fill-Poly 60 @( @(668,1292), @(684,1292), @(726,1216), @(716,1210) )
Fill-Poly 60 @( @(668,1292), @(684,1292), @(744,1256), @(738,1246) )
Fill-Poly 60 @( @(668,1292), @(684,1292), @(652,1198), @(642,1204) )
Fill-Poly 60 @( @(668,1292), @(684,1292), @(624,1220), @(618,1230) )
Fill-Poly 60 @( @(668,1292), @(684,1292), @(608,1258), @(606,1270) )
Fill-Poly 60 @( @(668,1292), @(684,1292), @(678,1186), @(670,1186) )
Fill-Poly 25 @( @(673,1290), @(679,1290), @(660,1168), @(654,1170) )  # herb stem 1
Fill-Poly 25 @( @(673,1290), @(679,1290), @(679,1158), @(673,1158) )  # herb stem 2
Fill-Poly 25 @( @(673,1290), @(679,1290), @(699,1174), @(693,1170) )  # herb stem 3
Fill-Ellipse 25 677 1150 13 10                                        # cream flower head

# ---------------------------------------------------------------- 14. foreground grass fringe, left third
Fill-Rect 185 0 1372 341 41
for ($x = 6; $x -lt 341; $x += 26) { Fill-Ellipse 185 $x 1372 11 16 }

# ---------------------------------------------------------------- 15. HUD regions
Fill-Rect 20 0 0 $W 138                      # top strip
Fill-Rect 90  40 55 280 40                   # location name region
Fill-Rect 90 700 55 180 40                   # banked energy region
Fill-Ellipse 90 940 75 12 12                 # sync dot
Fill-Rect 20 0 1413 $W 123                   # bottom tab bar
$centers = @(85, 256, 427, 597, 768, 939)
for ($i = 0; $i -lt 6; $i++) {
  $c = $centers[$i]
  if ($i -eq 0) { Fill-Rect 130 ($c - 34) 1440 68 68 }   # active tab, Adventure
  else          { Fill-Rect  90 ($c - 30) 1444 60 60 }
}

# ---------------------------------------------------------------- 16. gather interaction card
Fill-Rect 45 586 1030 220 88

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("wrote " + $OutPath)
