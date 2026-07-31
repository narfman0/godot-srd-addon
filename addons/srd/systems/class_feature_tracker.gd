class_name ClassFeatureTracker
extends RefCounted

# Per-short-rest charges (reset on short or long rest)
var action_surge_used: bool = false
var second_wind_used: bool = false
var arcane_recovery_used: bool = false  # per long rest
var channel_divinity_uses: int = 0
var channel_divinity_max: int = 0

func _init(class_data: ClassData) -> void:
	channel_divinity_max = SRDClassFeatures.channel_divinity_count(class_data, 1)

func short_rest_reset(class_data: ClassData, level: int) -> void:
	action_surge_used = false
	second_wind_used = false
	channel_divinity_uses = 0
	channel_divinity_max = SRDClassFeatures.channel_divinity_count(class_data, level)

func long_rest_reset(class_data: ClassData, level: int) -> void:
	short_rest_reset(class_data, level)
	arcane_recovery_used = false
