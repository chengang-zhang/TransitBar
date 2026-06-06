# Transit Data Resources

Static GTFS feeds are stored as agency-named `.bundle` directories so Xcode copies each feed as a folder instead of flattening shared filenames like `stops.txt` and `routes.txt`.

- `Sound Transit.bundle`
- `King County.bundle`

`StaticGtfsTransitRepository` namespaces parsed GTFS IDs by feed before merging schedules. This prevents stop, trip, route, and service ID collisions across agencies.
