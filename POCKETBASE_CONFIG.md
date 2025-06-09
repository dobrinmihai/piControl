# PocketBase Configuration for piControl

## Required Collections

### 1. Users Collection (should already exist)
- Default PocketBase users collection
- No additional configuration needed

### 2. Devices Collection
Create a collection named `devices` with the following fields:

**Required Fields:**
- `device_name` (text, required) - The display name of the device
- `mac_addr` (text, required) - MAC address of the device  
- `ip_addr` (text, required) - IP address of the device
- `device_type` (text, required) - Type of device (e.g., "raspberrypi", "esp32")

**Additional Field to Add:**
- `owner` (relation to users, required) - The user who owns this device

**Steps to Add Owner Field:**
1. Go to your PocketBase admin interface (usually http://localhost:8090/_/)
2. Navigate to Collections → devices
3. Click "Add field" 
4. Select "Relation" field type
5. Set field name as: `owner`
6. Set relation collection to: `users`
7. Set relation type to: `Single relation`
8. Check "Required" checkbox
9. Save the field

**API Rules (set these AFTER adding the owner field):**
- **List/View rule:** `owner = @request.auth.id`
- **Create rule:** `@request.auth.id != ""`  
- **Update rule:** `owner = @request.auth.id`
- **Delete rule:** `owner = @request.auth.id`

**Important:** Leave the API rules empty until you've added the owner field and migrated existing data!

## Migration Steps for Existing Devices

If you already have devices in your collection without owner fields:

1. **Add the owner field** (follow steps above)
2. **Update existing devices** to assign them to a user:
   - Go to Collections → devices → Records
   - For each device, click edit and assign an owner from the users dropdown
   - Or use the PocketBase API/admin interface to bulk update

3. **Set API rules** once all devices have owners:
   ```
   List/View rule: owner = @request.auth.id
   Create rule: @request.auth.id != ""
   Update rule: owner = @request.auth.id  
   Delete rule: owner = @request.auth.id
   ```

## Current Application Behavior

The application has been updated to handle the migration gracefully:
- ✅ New devices will automatically get the owner field set
- ✅ API endpoints will work with or without the owner field
- ✅ Device queries will fall back to name-only filtering if owner field doesn't exist
- ⚠️ Full security will only be active once the owner field is added and API rules are set

### 3. Api_clients Collection (if using API client settings)
Create a collection named `api_clients` with the following fields:

**Fields:**
- `user` (relation to users, required) - The user who owns these settings
- `host` (text, required) - API host URL
- `apiKey` (text, required) - API key for the external service

**API Rules:**
- **List/View rule:** `user = @request.auth.id`
- **Create rule:** `@request.auth.id != ""`
- **Update rule:** `user = @request.auth.id`  
- **Delete rule:** `user = @request.auth.id`

## Authentication Settings

1. **Auth providers:** Enable email/password authentication
2. **User registration:** Disable self-registration if you want admin-only registration
3. **Email verification:** Configure as needed
4. **Password requirements:** Set minimum length and complexity as needed

## Important Notes

- The `owner` field in devices should be automatically set to `@request.auth.id` when creating devices via the API
- Users can only see and manage devices they own
- The API endpoints now require authentication and will return 401 for unauthenticated requests
- All device operations are filtered by the authenticated user's ID for security
