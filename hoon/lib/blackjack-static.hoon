::  blackjack/lib/blackjack-static.hoon
::  Static file serving for blackjack game - Phase 1
::
::  DEPLOYMENT OPTIONS:
::
::  Option A: File Loading (RECOMMENDED for development)
::  - Copy index.html, style.css, game.js, sprites.png to your desk's /app/blackjack/ directory
::  - Use scry arms below to load at runtime
::  - Easier to update during development
::
::  Option B: Embedded Cords (for production/distribution)
::  - Embed files as cords using crip and triple-quote syntax
::  - No external files needed
::  - Shown in commented examples below
::
|%
::
::  OPTION A: File Loading (runtime scry)
::  Uncomment these if files are in your desk
::
::  ++  index-html
::    .^  @t
::      %cx
::      /(scot %p our.bowl)/blackjack/(scot %da now.bowl)/app/blackjack/index/html
::    ==
::
::  ++  style-css
::    .^  @t
::      %cx
::      /(scot %p our.bowl)/blackjack/(scot %da now.bowl)/app/blackjack/style/css
::    ==
::
::  ++  game-js
::    .^  @t
::      %cx
::      /(scot %p our.bowl)/blackjack/(scot %da now.bowl)/app/blackjack/game/js
::    ==
::
::
::  OPTION B: Embedded content (for self-contained distribution)
::  Using placeholders - replace with actual content for production
::
++  index-html
  %-  crip
  '''
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <title>Blackjack - NockApp</title>
    <link rel="stylesheet" href="/blackjack/style.css">
  </head>
  <body>
    <h1>Blackjack NockApp - Phase 1</h1>
    <p>Replace this with your full index.html content</p>
    <p>For development, use file loading method (see comments above)</p>
    <script src="/blackjack/game.js"></script>
  </body>
  </html>
  '''
::
++  style-css
  %-  crip
  '''
  /* Placeholder CSS - replace with actual style.css content */
  body {
    font-family: "MS Sans Serif", Arial, sans-serif;
    background: #008080;
  }
  '''
::
++  game-js
  %-  crip
  '''
  // Placeholder JS - replace with actual game.js content
  console.log('Blackjack NockApp Phase 1');
  '''
::
::  For sprites.png, you'll need to:
::  1. Convert PNG to base64
::  2. Store as @t (cord)
::  3. Decode when serving
::  OR: Keep in desk and serve via scry
::
++  sprites-png
  ::  Placeholder - in production, load from desk or embed as base64
  *@
--
