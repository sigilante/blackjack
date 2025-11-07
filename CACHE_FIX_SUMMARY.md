# HTTP Cache Bug Fix Summary

## The Bug
The HTTP driver was using a single `Option<CachedResponse>` instead of a map, causing ALL requests under the same parent path (e.g., `/blackjack/*`) to return the same cached response, regardless of the actual URI.

## The Fix
Change the cache from a single optional response to a HashMap keyed by URI. Also add a uri_map to track request ID → URI mapping since the effect handler only receives the request ID, not the full request.

### Changes Made (9 locations)

#### 1. Line 346-351: Cache and URI Map Declaration
**OLD:**
```rust
let channel_map = RwLock::new(HashMap::<u64, Responder>::new());
let regular_cache = Arc::new(RwLock::new(Option::<CachedResponse>::None));
let htmx_cache = Arc::new(RwLock::new(Option::<CachedResponse>::None));
```

**NEW:**
```rust
let channel_map = RwLock::new(HashMap::<u64, Responder>::new());
// FIX: Add URI map to track request ID -> URI for cache keying
let uri_map = RwLock::new(HashMap::<u64, String>::new());
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

#### 4. Line ~446: Store URI when processing request
**NEW CODE:**
```rust
channel_map.write().await.insert(msg.id, msg.resp);
// FIX: Store URI for this request ID so we can use it as cache key later
uri_map.write().await.insert(msg.id, msg.uri.to_string());
```

#### 5. Lines ~637-650: Cache Storage (retrieve URI from map)
**OLD:**
```rust
if status == StatusCode::OK {
    let cached_response = CachedResponse::new(status, header_vec.clone(), body.clone());
    if tag_val == tas!(b"htmx") || tag_val == tas!(b"h-cache") {
        debug!("caching HTMX response (htmx or h-cache effect)");
        *htmx_cache.write().await = Some(cached_response);
    } else {
        debug!("caching regular response (res or cache effect)");
        *regular_cache.write().await = Some(cached_response);
    }
}
```

**NEW:**
```rust
if status == StatusCode::OK {
    // FIX: Retrieve the URI for this request ID from uri_map
    if let Some(request_uri) = uri_map.read().await.get(&id).cloned() {
        let cached_response = CachedResponse::new(status, header_vec.clone(), body.clone());
        if tag_val == tas!(b"htmx") || tag_val == tas!(b"h-cache") {
            debug!("caching HTMX response for {} (htmx or h-cache effect)", request_uri);
            htmx_cache.write().await.insert(request_uri, cached_response);
        } else {
            debug!("caching regular response for {} (res or cache effect)", request_uri);
            regular_cache.write().await.insert(request_uri, cached_response);
        }
    }
}
```

#### 6-9. Lines ~495, ~506, ~665: Clean up uri_map (3 locations)
**Add after each `channel_map.write().await.remove(&id)`:**
```rust
uri_map.write().await.remove(&id);
```

This prevents memory leaks by cleaning up the URI mapping when the request is completed.

## Result
After this fix, the cache will properly store responses keyed by full URI path, so:
- `/blackjack` returns the index.html
- `/blackjack/style.css` returns the CSS file
- `/blackjack/game.js` returns the JavaScript file
- `/blackjack/img/sprites.png` returns the PNG image

Each with the correct Content-Type header!
