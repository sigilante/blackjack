# HTTP Cache Bug Fix Summary

## The Bug
The HTTP driver was using a single `Option<CachedResponse>` instead of a map, causing ALL requests under the same parent path (e.g., `/blackjack/*`) to return the same cached response, regardless of the actual URI.

## The Fix
Change the cache from a single optional response to a HashMap keyed by URI.

### Changes Made (4 locations)

#### 1. Line 358-359: Cache Declaration
**OLD:**
```rust
let regular_cache = Arc::new(RwLock::new(Option::<CachedResponse>::None));
let htmx_cache = Arc::new(RwLock::new(Option::<CachedResponse>::None));
```

**NEW:**
```rust
let regular_cache = Arc::new(RwLock::new(HashMap::<String, CachedResponse>::new()));
let htmx_cache = Arc::new(RwLock::new(HashMap::<String, CachedResponse>::new()));
```

#### 2. Lines 371 & 381: Cache Invalidation
**OLD:**
```rust
*regular_cache.write().await = None;
// and
*htmx_cache.write().await = None;
```

**NEW:**
```rust
regular_cache.write().await.clear();
// and
htmx_cache.write().await.clear();
```

#### 3. Line 407: Cache Lookup
**OLD:**
```rust
if let Some(cached) = &*cache_read {
```

**NEW:**
```rust
if let Some(cached) = cache_read.get(&msg.uri.to_string()) {
```

#### 4. Lines 527 & 530: Cache Storage
**OLD:**
```rust
*htmx_cache.write().await = Some(cached_response);
// and
*regular_cache.write().await = Some(cached_response);
```

**NEW:**
```rust
htmx_cache.write().await.insert(msg.uri.to_string(), cached_response);
// and
regular_cache.write().await.insert(msg.uri.to_string(), cached_response);
```

## Result
After this fix, the cache will properly store responses keyed by full URI path, so:
- `/blackjack` returns the index.html
- `/blackjack/style.css` returns the CSS file
- `/blackjack/game.js` returns the JavaScript file
- `/blackjack/img/sprites.png` returns the PNG image

Each with the correct Content-Type header!
