# WadiniSafe Firestore Schema

## 1. Users & Roles

### `admins/{adminId}`
*   **uid**: string (Auth UID)
*   **email**: string
*   **displayName**: string
*   **role**: string ('super_admin', 'support')
*   **createdAt**: timestamp

### `drivers/{driverId}`
*   **uid**: string (Auth UID)
*   **personalInfo**:
    *   **name**: string
    *   **phone**: string
    *   **photoUrl**: string
*   **status**: string ('pending', 'approved', 'rejected', 'suspended')
*   **isOnline**: boolean
*   **lastLocation**:
    *   **geohash**: string (for geo queries)
    *   **lat**: number
    *   **lng**: number
    *   **heading**: number
    *   **speed**: number
    *   **updatedAt**: timestamp
*   **activeRideId**: string | null
*   **rating**:
    *   **avg**: number
    *   **count**: number
*   **vehicleId**: string (Link to `vehicles` collection)
*   **fcmToken**: string (for push notifications)

### `clients/{clientId}`
*   **uid**: string (Auth UID)
*   **personalInfo**:
    *   **name**: string
    *   **phone**: string
    *   **photoUrl**: string
*   **status**: string ('approved', 'suspended')
*   **activeRideId**: string | null
*   **rating**:
    *   **avg**: number
    *   **count**: number
*   **fcmToken**: string

## 2. Core Entities

### `vehicles/{vehicleId}`
*   **driverId**: string
*   **plateNumber**: string
*   **model**: string
*   **color**: string
*   **type**: string ('taxi', 'bus', 'van')
*   **capacity**: number
*   **filters**:
    *   **isSchoolBus**: boolean
    *   **isUniversityBus**: boolean
    *   **hasAC**: boolean
*   **status**: string ('active', 'maintenance')

### `stands/{standId}`
*   **name**:
    *   **ar**: string
    *   **en**: string
*   **location**:
    *   **lat**: number
    *   **lng**: number
    *   **geohash**: string
*   **capacity**: number
*   **type**: string ('taxi_stand', 'bus_stop')

### `areas/{areaId}`
*   **name**:
    *   **ar**: string
    *   **en**: string
*   **coordinates**: GeoPoint (Center)
*   **radiusKm**: number

### `pricing/{pricingId}`
*   **fromAreaId**: string
*   **toAreaId**: string
*   **prices**:
    *   **baseLBP**: number
    *   **baseUSD**: number
    *   **perKmLBP**: number
    *   **perKmUSD**: number
    *   **perMinuteLBP**: number
    *   **perMinuteUSD**: number

## 3. Operations

### `rides/{rideId}`
*   **clientId**: string
*   **driverId**: string | null
*   **status**: string ('requested', 'accepted', 'on_the_way', 'in_progress', 'completed', 'canceled')
*   **pickup**:
    *   **lat**: number
    *   **lng**: number
    *   **address**: string
    *   **geohash**: string
*   **dropoff**:
    *   **lat**: number
    *   **lng**: number
    *   **address**: string
*   **price**:
    *   **estimatedLBP**: number
    *   **estimatedUSD**: number
    *   **finalLBP**: number
    *   **finalUSD**: number
*   **timestamps**:
    *   **created**: timestamp
    *   **accepted**: timestamp (nullable)
    *   **started**: timestamp (nullable)
    *   **completed**: timestamp (nullable)
*   **cancellationReason**: string (nullable)

### `rides/{rideId}/messages/{messageId}`
*   **senderId**: string
*   **text**: string
*   **type**: string ('text', 'image', 'audio')
*   **timestamp**: timestamp
*   **readBy**: array<string>

### `ratings/{ratingId}`
*   **rideId**: string
*   **fromUserId**: string
*   **toUserId**: string
*   **role**: string ('driver' -> 'client' or 'client' -> 'driver')
*   **score**: number (1-5)
*   **comment**: string
*   **timestamp**: timestamp

### `reports/{reportId}`
*   **reporterId**: string
*   **reportedId**: string
*   **rideId**: string
*   **category**: string ('rudeness', 'unsafe_driving', 'no_show', 'other')
*   **description**: string
*   **status**: string ('pending', 'investigating', 'resolved')
*   **timestamp**: timestamp

---

## 4. Query Indexes

### Drivers
*   `status` ASC, `lastLocation.geohash` ASC (For finding nearby active drivers)

### Rides
*   `clientId` ASC, `timestamps.created` DESC (Client ride history)
*   `driverId` ASC, `timestamps.created` DESC (Driver ride history)
*   `status` ASC, `pickup.areaId` ASC (Admin dashboard filtering)

