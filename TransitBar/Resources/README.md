# Transit Data Resources

Static GTFS feeds are stored as `.bundle` directories so Xcode copies each feed as a folder instead of flattening shared filenames like `stops.txt` and `routes.txt`.

- `Puget Sound.bundle`
- `Sound Transit.bundle`
- `King County.bundle`

`StaticGtfsTransitRepository` now loads the consolidated Puget Sound feed by default. The older Sound Transit and King County bundles remain in resources for comparison and migration testing.

The repository namespaces parsed GTFS IDs by feed before merging schedules. This prevents stop, trip, route, and service ID collisions across feeds.
