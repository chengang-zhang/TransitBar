# Transit Data Resources

Static GTFS feeds are stored as `.bundle` directories so Xcode copies each feed as a folder instead of flattening shared filenames like `stops.txt` and `routes.txt`.

- `Puget Sound.bundle`
- `Sound Transit.bundle`
- `King County.bundle`

`StaticGtfsTransitRepository` now loads the consolidated Puget Sound feed by default. The older Sound Transit and King County bundles remain in resources for comparison and migration testing.

The repository namespaces parsed GTFS IDs by feed before merging schedules. This prevents stop, trip, route, and service ID collisions across feeds.

`Puget Sound.bundle/stop_times.txt` is split into `stop_times.txt.part00`, `stop_times.txt.part01`, and so on because the consolidated file is larger than common Git hosting file-size limits. `GTFSParser` reads the normal file when present and otherwise joins the numbered parts in order.
