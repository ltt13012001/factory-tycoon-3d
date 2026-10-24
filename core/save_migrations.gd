## Upgrades old save dictionaries step by step to CURRENT_VERSION.
## When the save format changes: bump CURRENT_VERSION and add a
## _from_<old>() function that rewrites the dictionary in place.
class_name SaveMigrations
extends RefCounted

const CURRENT_VERSION := 1


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 0))
	if version > CURRENT_VERSION:
		push_error("Save file is from a newer game version (%d)." % version)
		return {}
	while version < CURRENT_VERSION:
		match version:
			0:
				data = _from_0(data)
		version += 1
		data.save_version = version
	return data


## Version 0 never shipped; it only marks files without a version field.
static func _from_0(data: Dictionary) -> Dictionary:
	return data
