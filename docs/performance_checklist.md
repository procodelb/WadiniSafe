
# Performance Checklist for 5000+ Users

## Firestore & Database Optimization
- [ ] **Limit Snapshot Listeners**: Use `limit()` on all queries. Avoid open-ended streams.
- [ ] **Throttling**: Ensure `LocationService` throttles writes to max 1 update per 5-10 seconds.
- [ ] **Paged Queries**: Use `startAfter` or `limit` for lists (Users, Rides History).
- [ ] **Index Optimization**: Ensure composite indexes exist for complex queries (e.g., `status` + `areaId`).
- [ ] **Sharding**: If write rate > 500/sec, shard the `counters` collection (not expected for 5000 users, but good to know).
- [ ] **Data Retention**: Implement a Cloud Function to archive old rides (> 30 days) to a cold storage or separate collection.

## Map & Geo Queries
- [ ] **Radius Limit**: Restrict `getNearbyDrivers` radius to reasonable max (e.g., 5-10km).
- [ ] **Marker Clustering**: If displaying > 100 markers, use `flutter_map_marker_cluster`.
- [ ] **Tile Caching**: Ensure `flutter_map` caches tiles to reduce network usage.
- [ ] **Geohash Precision**: Use appropriate precision (6 chars ~= 1.2km) to filter coarse updates first.

## Application Logic
- [ ] **Debounce Inputs**: Debounce search fields (address search) to minimize API calls.
- [ ] **Image Optimization**: Use `cached_network_image` with `memCacheWidth` to reduce memory usage.
- [ ] **Background Services**: Use `flutter_background_service` cautiously; stop GPS when app is killed or user is offline.
- [ ] **State Management**: Use `select` in Riverpod to rebuild widgets only when specific fields change.

## Security & Costs
- [ ] **Security Rules**: Enforce `request.auth != null` on all data.
- [ ] **Field Masks**: Use `update()` with specific fields instead of `set()` to prevent overwriting.
- [ ] **App Check**: Enable Firebase App Check to prevent abuse from non-app sources.
