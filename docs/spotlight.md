# Spotlight Re-indexing on macOS

## Force a Full Re-index

To force Spotlight to rebuild its index completely:

```bash
sudo mdutil -E /
```

This erases the existing index and triggers a full rebuild.

## Re-index a Specific Volume

To re-index only a particular drive:

```bash
sudo mdutil -E /Volumes/YourDriveName
```

## Reset Spotlight (If Stuck)

If Spotlight is completely unresponsive, disable and re-enable indexing:

```bash
sudo mdutil -a -i off
sudo mdutil -a -i on
```

## Check Indexing Status

To see whether indexing is enabled and its current state:

```bash
mdutil -s /
```

## Notes

- Re-indexing can take minutes to hours depending on data volume
- Progress is visible by clicking the Spotlight icon in the menu bar during indexing
- The `-a` flag applies the command to all volumes
