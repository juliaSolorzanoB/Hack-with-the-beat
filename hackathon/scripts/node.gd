extends Node

func _ready():
	var riddim_path = "res://song_data/riddim.json"
	var output_path = "res://song_data/riddim_processed.json"

	var raw = FileAccess.get_file_as_string(riddim_path)
	var riddim_data = JSON.parse_string(raw)

	var beats: Array = []

	for i in range(riddim_data.size() - 1):
		var start_time = riddim_data[i]["time"]
		var bpm = riddim_data[i]["bpm"]
		var next_start_time = riddim_data[i + 1]["time"]

		var beat_interval = 60.0 / bpm
		var t = start_time

		while t < next_start_time:
			beats.append({ "time": snappedf(t, 0.0001), "type": "beat" })
			t += beat_interval

	# Optional: include final segment
	var final_start_time = riddim_data[riddim_data.size() - 1]["time"]
	var final_bpm = riddim_data[riddim_data.size() - 1]["bpm"]
	var beat_interval = 60.0 / final_bpm
	var end_time = final_start_time + 8 * beat_interval  # Add 8 beats after last entry

	var t = final_start_time
	while t < end_time:
		beats.append({ "time": snappedf(t, 0.0001), "type": "beat" })
		t += beat_interval

	# Save to JSON
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(beats, "\t"))
	file.close()

	print("✅ Processed beats saved to riddim_processed.json with ", beats.size(), " entries.")
