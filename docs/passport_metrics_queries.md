# Passport Metrics Queries

CloudWatch queries for monitoring passport verification metrics.

## Basic Metrics

**Passport validations by vendor:**
```sql
fields @timestamp, properties.event_properties.vendor as vendor
| filter name = "passport_validation"
| stats count() by vendor
```

**Success rate by vendor:**
```sql
fields properties.event_properties.vendor as vendor, properties.event_properties.success as success
| filter name = "passport_validation"
| stats count() as total, sum(success) as successful by vendor
| fields vendor, total, successful, (successful * 100.0 / total) as success_rate
```

**Tampering detection rate:**
```sql
fields properties.event_properties.vendor as vendor
| filter name = "passport_tampering_detected"
| stats count() by vendor
```

**Passport errors:**
```sql
fields properties.event_properties.vendor as vendor, properties.event_properties.reason_codes as codes
| filter name = "passport_validation" and properties.event_properties.success = 0
| stats count() by vendor, codes
| sort count desc
```

**Users who completed IDV with passport:**
```sql
fields properties.event_properties.vendor as vendor
| filter name = "proofed_with_passport"
| stats count() by vendor
```

## Time-based

**Daily passport volumes:**
```sql
fields properties.event_properties.vendor as vendor
| filter name = "passport_validation"
| stats count() by vendor, bin(@timestamp, 1d) as day
| sort day desc
```

**Tampering rate over time:**
```sql
fields properties.event_properties.vendor as vendor
| filter name = "passport_tampering_detected"
| stats count() by vendor, bin(@timestamp, 1h) as hour
| sort hour desc
```