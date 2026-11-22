extends SceneTree
## Real HTTP + headless scene integration using synthetic providers. Never a live-model test.
const CaseDB = preload("res://scripts/core/case_db.gd")
const VisitState = preload("res://scripts/core/visit_state.gd")
const PatientAgent = preload("res://scripts/core/patient_agent.gd")
const ModelClient = preload("res://scripts/core/model_client.gd")
const PlayDriver = preload("res://tests/play_driver.gd")
const MainScript = preload("res://scripts/ui/main.gd")
const VoiceClip = preload("res://scripts/core/voice_clip.gd")
const Gfx = preload("res://scripts/ui/gfx.gd")
const Lang = preload("res://scripts/core/lang.gd")
const NOVEL := "Before we go on, will you explain what this means for my night shift?"
# what the proxy's synthetic speech service "hears" in every clip (agent_proxy/src/providers.mjs)
const MOCK_TRANSCRIPT := "This is a mock transcript. No speech service heard you."
var urls: Dictionary = {}
var passed := 0
var failed := 0
var serial := 0
var rules: Dictionary
var client: ModelClient

func _initialize() -> void:
	# English whatever language a player saved: the checks below read English words
	Lang.pin("en")
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			urls[parts[0]] = parts[1]
	create_timer(170.0, true, false, true).timeout.connect(func(): quit(2))
	if urls.has("launch-check"):
		test_launcher(str(urls["launch-check"]))
	else:
		_run()

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		print("FAIL: " + label)

func new_agent(v: VisitState) -> PatientAgent:
	serial += 1
	var model_rules := rules.duplicate(true)
	model_rules["agent"]["ask_answers"] = "model"
	var a := PatientAgent.new(model_rules, client, 123)
	a.run_id = "btc-http-qa"
	a.begin_visit(v, "btc-http-visit-%d" % serial, 123)
	a.set_mode("model")
	return a

func _run() -> void:
	await process_frame
	var db := CaseDB.load_all()
	rules = db.rules
	client = ModelClient.new()
	root.add_child(client)
	client.timeout_ms = int(rules.agent.timeout_ms)
	client.voice_timeout_ms = int(rules.agent.voice.timeout_ms)
	client.base_url = str(urls.normal)
	for id in db.cases:
		var c: Dictionary = db.cases[id]
		var v := VisitState.new(c, rules)
		var a := new_agent(v)
		var topic: Dictionary = c.topics[0]
		var ev := {"type": "ask", "id": topic.id, "outcome": "answer", "text": topic.q}
		var d: Dictionary = await a.decide(ev, v.snapshot(), v.legal_moves_for_ask(str(topic.id)), v.open_signs(ev))
		check(d.get("source") == "model", str(id) + ": HTTP response used")
		check(d.get("reply") == NOVEL, str(id) + ": speech survives unchanged")
		check(bool(d.get("meta", {}).get("mock", false)), "synthetic response labelled mock")
		a.record.append("reaction", d.reaction)
		a.record.append("patient", d.reply)
		v.apply_ask(str(topic.id), str(d.move), str(d.reply))
		ev = {"type": "check", "id": "grip", "text": "Please hold this handle, then release it."}
		d = await a.decide(ev, v.snapshot(), v.legal_moves_for_check("grip"))
		check(d.get("source") == "model" and bool(d.get("cooperates", false)), "tool consent through HTTP")
		var result := v.apply_check("grip", str(d.move), true)
		check(result.result == "granted", "AI cooperation reaches tool state")
		check(a.record.entries.size() >= 3, "visit history carries actual conversation")
	await test_sign_matrix(db)
	for scenario in ["timeout", "invalid", "slow"]:
		client.base_url = str(urls[scenario])
		var v := VisitState.new(db.cases.kip, rules)
		var a := new_agent(v)
		var started := Time.get_ticks_msec()
		var d: Dictionary = await a.decide({"type":"ask","id":"why","outcome":"answer","text":"What happened?"}, v.snapshot(), ["answer"])
		check(d.source == "fallback", scenario + ": explicit offline fallback")
		var expected := "http_504:upstream_timeout" if scenario == "timeout" else ("http_422:invalid_model_output" if scenario == "invalid" else "timeout")
		check(d.fallback_reason == expected, scenario + ": correct failure reason")
		check(Time.get_ticks_msec() - started < int(rules.agent.timeout_ms) + 700, scenario + ": bounded wait")
	client.base_url = str(urls.normal)
	await test_speech_route(db.cases.kip)
	await test_scene()
	await test_optional_turns()
	await test_visit_timeline()
	for language in ["en", "zh"]:
		await test_talk_rules(language)
	Lang.pin("en")
	client.queue_free()
	await process_frame
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

## Cross every pair of speech and temper conditions for every patient in both languages.
func test_sign_matrix(db: Dictionary) -> void:
	for language in ["en", "zh"]:
		Lang.pin(language)
		for id in db.templates:
			var template: Dictionary = db.templates[id]
			for speech in ["normal", "broken"]:
				for temper in ["normal", "broken"]:
					var signs := {"speech": template.signs.speech[speech][0].id, "temper": template.signs.temper[temper][0].id}
					var c := CaseDB.compose(template, {"signs": signs, "truth": "stable" if speech == "normal" and temper == "normal" else "drifting"})
					var v := VisitState.new(c, rules)
					var a := new_agent(v)
					a.run_id = "btc-sign-matrix"
					var evidence: Array = c.rows.speech.evidence
					var id_to_ask := str(evidence[0]).trim_prefix("ask:")
					v.press()
					while not v.answered.has(id_to_ask):
						v.apply_ask(id_to_ask, str(v.legal_moves_for_ask(id_to_ask)[0]))
					var action := {"type": "reassure", "id": "calm", "text": Lang.t("All right.")}
					var d: Dictionary = await a.decide(action, v.snapshot(), [], v.open_signs(action))
					check(d.source == "model" and d.meta.get("mock") == true and not str(d.reply).is_empty()
						and (str(d.reply) == NOVEL) == (language == "en"), "HTTP mock reply for %s/%s/%s/%s" % [id, language, speech, temper])
	Lang.pin("en")


## The speech route over real HTTP, below the screen: a clip's words, and each way it can fail.
## The clips are generated tones. No microphone is opened and no speech service is called.
func test_speech_route(c: Dictionary) -> void:
	var one := VoiceClip.new(48000.0, 10.0)
	var frames := PackedVector2Array()
	frames.resize(48000)
	for i in frames.size():
		var s: float = sin(TAU * 220.0 * float(i) / 48000.0) * 0.3
		frames[i] = Vector2(s, s)
	one.push(frames)
	var wav := one.wav()
	var a := new_agent(VisitState.new(c, rules))
	var t: Dictionary = await a.transcribe(wav)
	check(t.get("ok") == true and t.get("text") == MOCK_TRANSCRIPT, "speech: a clip's words come back over HTTP")
	check(t.get("mock") == true, "speech: the synthetic transcript is labelled mock")
	check(a.calls_this_visit == 0 and a.voice_clips_this_visit == 1, "speech: a clip is counted as a clip, not as a line said")
	for pair in [["stt_empty", "http_422:no_speech"], ["stt_fail", "http_502:provider_error"], ["timeout", "http_504:upstream_timeout"],
			["invalid", "http_422:invalid_transcript"]]:
		client.base_url = str(urls[pair[0]])
		var started := Time.get_ticks_msec()
		t = await a.transcribe(wav)
		check(t.get("ok") == false and t.get("error") == pair[1], "speech, %s: the reason reaches the game (%s)" % [pair[0], str(t.get("error"))])
		check(Time.get_ticks_msec() - started < int(rules.agent.voice.timeout_ms) + 700, "speech, %s: bounded wait" % pair[0])
	# the game's own deadline, against a service that answers after it
	client.base_url = str(urls.stt_slow)
	client.voice_timeout_ms = 300
	t = await a.transcribe(wav)
	check(t.get("ok") == false and t.get("error") == "timeout", "speech: the game's own deadline ends a slow request")
	client.voice_timeout_ms = int(rules.agent.voice.timeout_ms)
	# the longest clip the game can make
	var most := VoiceClip.new(48000.0, float(rules.agent.voice.max_seconds))
	while not most.full():
		most.push(frames)
	client.base_url = str(urls.normal)
	t = await a.transcribe(most.wav())
	check(t.get("ok") == true and is_equal_approx(most.seconds(), float(rules.agent.voice.max_seconds)), "speech: the longest clip is accepted whole")
	check(a.voice_clips_this_visit == 7, "speech: seven clips were sent, heard or not")


## Push-to-talk in model mode, through the real key entry points and real HTTP. The microphone is
## simulated (frames are handed to it; no device is opened) and the speech service is the proxy's
## synthetic one, whose transcript is a fixed sentence that says it is a mock.
func spoken_conversation(main: MainScript, driver: PlayDriver) -> void:
	var box = main.dialogue
	var hints: Dictionary = main.MIC_HINTS
	var settled := false
	client.base_url = str(urls.normal)
	await driver.settle()
	await process_frame
	var said: PackedVector2Array = driver.tone(0.8, 0.3)
	await process_frame
	# -- it is offered, and looks it
	check(main.mic.simulated, "the run's microphone is simulated")
	check(main._mic_why_not() == "", "with the patient AI service on, speaking is offered")
	check(box.chips.size() == 2 and not box.chips_dim, "SPEAK joins TYPE on the strip")
	var speak_rect: Rect2 = box.chip_rect("speak")      # where the buttons are on the screen
	var type_rect: Rect2 = box.chip_rect("type")
	check(speak_rect.size.x > 0.0 and Gfx.DIALOGUE.encloses(speak_rect) and Gfx.DIALOGUE.encloses(type_rect)
		and not speak_rect.intersects(type_rect) and speak_rect.end.x < type_rect.position.x, "the two buttons sit side by side inside the strip")
	driver.move(speak_rect.get_center())
	await process_frame
	await process_frame
	check(box.chip_hover == "speak" and main._hover_hint.begins_with("SPEAK [hold TAB]"), "hovering SPEAK says what it does")
	driver.move(Vector2(200, 262))
	await process_frame
	await process_frame

	# -- one working exchange
	var calls: int = main.agent.calls_this_visit
	var history: int = main.agent.record.entries.size()
	var clips: int = main.agent.voice_clips_this_visit
	var free_lines: int = int(main.visit.asked.get("free", 0))
	driver.key(KEY_TAB)
	check(main._mic_state == "listening" and main.mic.listening, "holding TAB opens the microphone")
	check(box.input_open and box.input_status == "listening" and main._base_hint == main.MIC_LISTEN_HINT, "the strip shows LISTENING and how to stop")
	main.mic.feed(said)
	await process_frame
	await process_frame
	check(box.input_level > 0.2, "the meter shows the voice")
	check(main.rig != null and main.rig.listening and not main.rig.thinking and not main.rig._bubble.visible,
		"the patient is seen listening while the microphone is open")
	await driver.seconds(0.6)
	check(box.input_seconds >= 0.5 and box.input_seconds < 3.0, "the clock counts while the key is held")
	check(AudioServer.get_bus_volume_db(0) < -17.0, "the clinic goes quiet while the microphone is open")
	driver.key(KEY_TAB)
	driver.key(KEY_ENTER)
	driver.key(KEY_T, 116)
	check(main._mic_state == "listening" and box.input_text == "" and main.agent.calls_this_visit == calls, "other keys wait while the microphone has the line")
	driver.key_release(KEY_TAB)
	check(main._mic_state == "transcribing" and not main.mic.listening and box.input_status == "transcribing"
		and main._base_hint == main.MIC_WAIT_HINT, "letting go closes the microphone and the words are written down")
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled, "the words come back")
	check(not main.rig.listening, "the listening pose ends with the clip")
	check(box.input_open and box.input_status == "" and box.input_text == MOCK_TRANSCRIPT, "they are put on the typing line for the doctor to check")
	check(main._base_hint == main.MIC_MOCK_HINT, "the hint says the mock transport heard nobody")
	check(main.agent.voice_clips_this_visit == clips + 1, "one clip was sent")
	check(main.agent.calls_this_visit == calls and main.agent.record.entries.size() == history and not main._thinking
		and int(main.visit.asked.get("free", 0)) == free_lines, "letting go of the key says nothing to the patient")
	settled = await driver.until(func() -> bool: return AudioServer.get_bus_volume_db(0) > -0.5, 5.0)
	check(settled, "the clinic's sound comes back")
	# the doctor corrects the words, then says them
	for i in "No speech service heard you.".length():
		driver.key(KEY_BACKSPACE)
	check(main._base_hint == main.SAY_VOICE_HINT, "editing brings the typing hint back, with the speak key in it")
	driver.type_text("Does the arm ever move by itself?")
	var corrected := "This is a mock transcript. Does the arm ever move by itself?"
	check(box.input_text == corrected, "the transcript is edited like anything typed")
	driver.key(KEY_ENTER)
	check(not box.input_open and box.speaker == "YOU" and " ".join(box.lines) == corrected, "ENTER says the words the doctor approved")
	check(not main.dialogue.has_menu(), "dictated question needs no confirmation")
	settled = await driver.until(func() -> bool: return main.visit.answered.has("implant") and not main._thinking and not main._lock, 20.0)
	check(settled and main.agent.calls_this_visit == calls, "dictated ASK uses intent and the authored implant answer")
	settled = await driver.until(func() -> bool: return box.speaker == main._patient_name() and " ".join(box.lines) == str(main.visit.topic("implant").a), 20.0)
	check(settled, "the patient's reply is shown as text, as always")
	check(main.agent.record.entries.size() == history + 3 and main.agent.record.entries[history] == {"role":"doctor","text":corrected}
		and main.agent.record.entries[history+1] == {"role":"action","text":"ask:implant:answer"},
		"the history holds the approved words, once")
	check(int(main.visit.asked.get("free", 0)) == free_lines, "the spoken question is recorded under implant only")

	# -- words spoken after typed ones are added to them
	await driver.settle()
	driver.key(KEY_T, 116)
	check(main._base_hint == main.SAY_VOICE_HINT, "the typing hint mentions the speak key when it can work")
	driver.type_text("Listen:")
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and box.input_open and box.input_text == "Listen: " + MOCK_TRANSCRIPT, "words spoken after typed ones are added to them")
	driver.key(KEY_ESCAPE)
	check(not box.input_open and main.agent.calls_this_visit == calls, "ESC takes the whole sentence back unsaid")

	# -- clips that are not worth sending are not sent
	clips = main.agent.voice_clips_this_visit
	driver.key(KEY_TAB)
	main.mic.feed(said)
	driver.key_release(KEY_TAB)
	check(main._mic_state == "" and not main.mic.listening and not box.input_open and main._base_hint == hints["tap"], "a tap: the hint says to hold the key")
	await driver.speak(0.8, 0.004, 0.6)
	check(main._mic_state == "" and not box.input_open and main._base_hint == hints["silence"], "silence: the hint says nothing was heard")
	await driver.speak(0.0, 0.0, 0.6)
	check(main._mic_state == "" and not box.input_open and main._base_hint == hints["no_audio"], "a microphone that gives no sound: the hint says to check it")
	check(main.agent.voice_clips_this_visit == clips and not main._thinking, "none of the three left the game")

	# -- throwing a clip away
	driver.key(KEY_TAB)
	main.mic.feed(said)
	await driver.seconds(0.5)
	driver.key(KEY_ESCAPE)
	check(main._mic_state == "" and not main.mic.listening and not box.input_open and main._base_hint == hints["cancelled"],
		"ESC while listening throws the clip away")
	driver.key_release(KEY_TAB)
	await process_frame
	check(main._mic_state == "" and main.agent.voice_clips_this_visit == clips, "the key coming up afterwards sends nothing")
	driver.key(KEY_T, 116)
	driver.type_text("Keep this")
	driver.key(KEY_TAB)
	main.mic.feed(said)
	await driver.seconds(0.5)
	driver.right_click()
	check(main._mic_state == "" and box.input_open and box.input_text == "Keep this" and box.input_status == "",
		"right-click throws the clip away and keeps what was typed")
	driver.key_release(KEY_TAB)
	driver.key(KEY_ESCAPE)
	check(not box.input_open and main.agent.voice_clips_this_visit == clips, "and still nothing was sent")

	# -- a device that is slow to open: the strip says so, and nothing is heard until it is ready
	main.mic.simulated_open_seconds = 0.4
	driver.key(KEY_TAB)
	await process_frame
	await process_frame
	check(main._mic_state == "listening" and main.mic.opening and box.input_status == "opening",
		"while the device opens, the strip says it is not listening yet")
	main.mic.feed(said)
	driver.key_release(KEY_TAB)
	check(main._mic_state == "" and not box.input_open and main._base_hint == hints["opening"],
		"letting go before it is ready sends nothing and the hint says to wait")
	driver.key(KEY_TAB)
	settled = await driver.until(func() -> bool: return not main.mic.opening, 5.0)
	await process_frame
	check(settled and main._mic_state == "listening" and box.input_status == "listening", "once it is open the strip says LISTENING")
	driver.key(KEY_ESCAPE)
	driver.key_release(KEY_TAB)
	check(main._mic_state == "" and main.agent.voice_clips_this_visit == clips, "and still nothing was sent")
	main.mic.simulated_open_seconds = 0.0

	# -- words that come back too late go nowhere
	client.base_url = str(urls.stt_slow)
	await driver.speak(0.8, 0.3, 0.6)
	check(main._mic_state == "transcribing" and box.input_status == "transcribing", "a slow service keeps the line waiting")
	driver.key(KEY_ENTER)
	driver.key(KEY_T, 116)
	check(main._mic_state == "transcribing" and not main._thinking and box.input_text == "", "ENTER cannot say words that are not there yet")
	driver.key(KEY_ESCAPE)
	check(main._mic_state == "" and not box.input_open and main._base_hint == hints["cancelled"],
		"ESC while the words are being written down throws them away")
	await driver.seconds(6.0)
	check(not box.input_open and box.input_text == "" and main._mic_state == "" and main.agent.calls_this_visit == calls,
		"the transcript that arrives afterwards is ignored")
	check(main.agent.voice_clips_this_visit == clips + 1, "the clip still counts against the visit")

	# -- ways the service can fail
	client.base_url = str(urls.stt_empty)
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and not box.input_open and main._base_hint == hints["no_speech"], "no words in the clip: the hint says so and the strip is as it was")
	client.base_url = str(urls.stt_fail)
	driver.key(KEY_T, 116)
	driver.type_text("Typed first")
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and box.input_open and box.input_text == "Typed first" and box.input_status == "" and main._base_hint.contains("(http_502)"),
		"a failing service: the hint names it and the typed words survive")
	driver.key(KEY_ESCAPE)
	client.base_url = str(urls.timeout)
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 30.0)
	check(settled and not box.input_open and main._base_hint == hints["slow"], "a service that never answers: the wait ends and the hint says it took too long")
	client.base_url = str(urls.stt_fancy)
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and box.input_text == "It's \"fine\", really.", "typographic quotes from a speech service become ones the counter font has")
	driver.key(KEY_ESCAPE)
	client.base_url = str(urls.normal)

	# -- the longest clip stops by itself and crosses the wire whole
	clips = main.agent.voice_clips_this_visit
	var most: PackedVector2Array = driver.tone(main.mic.max_seconds - 0.5, 0.3)
	var rest: PackedVector2Array = driver.tone(1.0, 0.3)
	await process_frame
	driver.key(KEY_TAB)
	main.mic.feed(most)
	await driver.seconds(0.6)
	check(main._mic_state == "listening" and absf(main.mic.seconds() - (main.mic.max_seconds - 0.5)) < 0.01, "a long clip is still being heard")
	main.mic.feed(rest)
	check(main._mic_state == "transcribing" and not main.mic.listening, "a full clip stops by itself, with the key still down")
	settled = await driver.until(func() -> bool: return main._mic_state == "", 30.0)
	check(settled and box.input_text == MOCK_TRANSCRIPT and main.agent.voice_clips_this_visit == clips + 1, "the longest clip is accepted whole")
	driver.key_release(KEY_TAB)
	await process_frame
	check(main._mic_state == "" and box.input_text == MOCK_TRANSCRIPT and main.agent.voice_clips_this_visit == clips + 1, "letting go afterwards sends nothing more")
	driver.key(KEY_ESCAPE)
	# a microphone that delivers nothing is closed by itself
	driver.key(KEY_TAB)
	settled = await driver.until(func() -> bool: return main._mic_state == "", main.mic.max_seconds + 4.0)
	check(settled and not main.mic.listening and main._base_hint == hints["no_audio"], "a held key with no sound ends by itself after the longest clip")
	driver.key_release(KEY_TAB)

	# -- the clip cap
	var cap: int = main.agent.max_voice_clips
	main.agent.max_voice_clips = main.agent.voice_clips_this_visit
	driver.key(KEY_TAB)
	check(main._mic_state == "" and not main.mic.listening and not box.input_open and main._base_hint == hints["clip_cap"],
		"past the visit's clip cap the microphone stays shut")
	driver.key_release(KEY_TAB)
	main.agent.max_voice_clips = cap

	# -- anything else the doctor does closes the microphone
	clips = main.agent.voice_clips_this_visit
	driver.key(KEY_TAB)
	main.mic.feed(said)
	await driver.seconds(0.5)
	driver.pad("ask")
	await process_frame
	check(main._mic_state == "" and not main.mic.listening and not box.input_open and box.has_menu(), "opening the question list closes the microphone")
	driver.key_release(KEY_TAB)
	await process_frame
	check(main.agent.voice_clips_this_visit == clips, "and its clip goes nowhere")
	driver.right_click()
	driver.key(KEY_TAB)
	main.mic.feed(said)
	await driver.seconds(0.5)
	main.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(main._mic_state == "" and not main.mic.listening and main._base_hint == hints["cancelled"],
		"losing the window closes the microphone: the key-up would never arrive")
	driver.key_release(KEY_TAB)
	check(main.agent.voice_clips_this_visit == clips, "nothing was sent")

	# -- the SPEAK button, held with the mouse
	await process_frame
	driver.move(speak_rect.get_center())
	main.pointer_down(speak_rect.get_center(), MOUSE_BUTTON_LEFT)
	check(main._mic_state == "listening" and main._mic_from == "chip" and box.input_open, "holding the mouse on SPEAK opens the microphone")
	main.mic.feed(said)
	await driver.seconds(0.6)
	driver.key_release(KEY_TAB)
	check(main._mic_state == "listening", "a key coming up does not end a clip the mouse is holding")
	main.pointer_up(speak_rect.get_center(), MOUSE_BUTTON_LEFT)
	check(main._mic_state == "transcribing", "letting the mouse go sends it")
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and box.input_text == MOCK_TRANSCRIPT, "and the words arrive on the line")
	driver.key(KEY_ESCAPE)
	driver.move(Vector2(200, 262))

	# -- a transcript too long for what is already typed
	driver.key(KEY_T, 116)
	driver.type_text("word ".repeat(20).strip_edges())
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and box.input_text.length() <= box.INPUT_MAX and box.input_text.begins_with("word word")
		and box.input_text.contains("This is a mock") and not box.input_text.contains("heard you")
		and main._base_hint == main.MIC_CUT_HINT, "words that do not all fit stop at the line's end, and the hint says to check")
	driver.key(KEY_ESCAPE)

	# -- a verdict while the words are still being written down; the next patient hears none of it
	client.base_url = str(urls.stt_slow)
	await driver.speak(0.8, 0.3, 0.6)
	check(main._mic_state == "transcribing", "a clip is on its way when the verdict is given")
	client.base_url = str(urls.normal)
	var second: String = str(main.visit.case_data.id)
	await driver.stamp("treat")
	check(main._mic_state == "" and not box.input_open, "a verdict closes the line and drops the clip")
	check(await driver.wait_for_slip(40.0), "the second visit ends")
	check(await driver.take_slip(), "a third patient is on the camera")
	check(await driver.buzz_in(), "third patient arrives")
	await driver.seconds(4.0)
	check(str(main.visit.case_data.id) != second and not box.input_open and box.input_text == "" and main._mic_state == "",
		"the last patient's words never reach the next one")
	check(main.agent.voice_clips_this_visit == 0, "the clip count starts again")
	await driver.settle()
	await driver.speak(0.8, 0.3, 0.6)
	settled = await driver.until(func() -> bool: return main._mic_state == "", 20.0)
	check(settled and box.input_text == MOCK_TRANSCRIPT and main.agent.voice_clips_this_visit == 1, "speaking works for the new patient")
	var calls3: int = main.agent.calls_this_visit
	driver.key(KEY_ENTER)
	settled = await driver.until(func() -> bool: return main.agent.calls_this_visit == calls3 + 1 and not main._thinking and not main._lock, 20.0)
	check(settled, "ENTER sends the words as they came back")
	var now := JSON.stringify(main.agent.record.entries)
	check(now.contains(MOCK_TRANSCRIPT) and not now.contains("Does the arm ever move"), "its history holds its own spoken line and nothing from the last patient")

	# -- the log: stages and numbers, never words or sound
	var stages := {}
	for rec in main.event_log.memory:
		if str(rec.get("type", "")) == "voice":
			var stage := str(rec.get("stage", ""))
			stages[stage] = int(stages.get(stage, 0)) + 1
	var all_stages := true
	for stage in ["listening", "sent", "transcript", "not_sent", "dropped", "failed", "refused"]:
		all_stages = all_stages and stages.has(stage)
	check(all_stages, "every stage of push-to-talk is in the event log: %s" % JSON.stringify(stages))
	var logged := JSON.stringify(main.event_log.memory)
	check(not logged.contains("mock transcript") and not logged.contains("Does the arm") and not logged.contains("UklGR"),
		"the log holds no spoken words and no audio")
	print("VOICE_SCENE session=%s clips_sent=%d" % [main.run_id, int(stages.get("sent", 0))])


## The typing line in model mode, through the real key entry points and real HTTP:
## repeated turns with one patient, then a second patient who must start clean.
func typed_conversation(main: MainScript, driver: PlayDriver) -> void:
	var first: String = str(main.visit.case_data.id)
	var said: Array = ["How do you like the music?", "Who is waiting for you at home?", "What would you do if I said no?"]
	var patience: int = main.visit.patience
	for i in said.size():
		await driver.settle()
		var before: int = main.agent.record.entries.size()
		var calls: int = main.agent.calls_this_visit
		driver.key(KEY_T, 116)
		check(main.dialogue.input_open, "typed turn %d: T opens the typing line in model mode" % i)
		driver.type_text(str(said[i]))
		check(main.dialogue.input_text == str(said[i]), "typed turn %d: the sentence is on the line" % i)
		driver.key(KEY_ENTER)
		check(not main.dialogue.input_open and main.dialogue.speaker == "YOU" and " ".join(main.dialogue.lines) == str(said[i]),
			"typed turn %d: ENTER says exactly what was typed" % i)
		check(await driver.until(func() -> bool: return main.agent.calls_this_visit == calls + 1 and not main._thinking and not main._lock, 20.0),
			"typed turn %d: one model call answers it" % i)
		check(await driver.until(func() -> bool: return main.dialogue.speaker != "YOU" and " ".join(main.dialogue.lines) == NOVEL, 20.0),
			"typed turn %d: the generated reply is shown" % i)
		check(main.agent.record.entries.size() == before + 3, "typed turn %d: doctor line, reaction and reply join the history" % i)
		var turn: Dictionary = main.agent.record.entries[before]
		check(str(turn.role) == "doctor" and str(turn.text) == str(said[i]), "typed turn %d: the history holds the doctor's own words" % i)
	check(main.visit.patience == patience, "after the first free line, talking costs no more patience")
	check(not main.visit.asked.has("free"), "small talk never enters the question ledger")
	check(main.agent.calls_this_visit == 6 and main.agent.fallbacks_this_visit == 0, "six dialogue calls, none fell back")
	check(main.clinic.corner_text.contains("6/%d" % main.agent.max_calls), "the corner shows the calls used out of the cap")
	var types := {}
	for rec in main.event_log.memory:
		types[str(rec.get("type", ""))] = int(types.get(str(rec.get("type", "")), 0)) + 1
	check(int(types.get("say", 0)) == 5, "each free line is logged")
	check(not JSON.stringify(main.event_log.memory).contains("like the music"), "the log holds no typed text")
	# next patient: the conversation must not follow
	await driver.settle()
	await driver.stamp("treat")
	check(await driver.wait_for_slip(40.0), "the first visit ends")
	check(await driver.take_slip(), "the next patient is on the camera")
	check(await driver.buzz_in(), "second patient arrives")
	var second: String = str(main.visit.case_data.id)
	check(second != first, "it is a different patient")
	check(main.agent.mode == "model" and main.agent.calls_this_visit == 0, "the call budget starts again")
	check(await driver.until(func()->bool: return main._beat_opening_done, 16.0), "the second opening finishes playing before its full words are expected")
	var carried := JSON.stringify(main.agent.record.entries)
	check(not carried.contains("like the music") and not carried.contains(NOVEL), "the new patient's history has nothing from the last one")
	check(main.agent.record.entries.size() == (main.visit.case_data.opening as Array).size(), "it starts from that patient's own opening lines")
	check(not main.dialogue.input_open and main.dialogue.input_text == "", "the typing line starts empty")
	await driver.settle()
	await driver.say("Hello. Would you like some music?")
	check(await driver.until(func() -> bool: return main.agent.calls_this_visit == 1 and not main._thinking and not main._lock, 20.0),
		"a typed line reaches the second patient")
	check(await driver.until(func() -> bool: return main.dialogue.speaker != "YOU" and " ".join(main.dialogue.lines) == NOVEL, 20.0),
		"and the second patient answers")
	var now := JSON.stringify(main.agent.record.entries)
	check(now.contains("Hello. Would you like some music?") and not now.contains("like the music"), "its history holds only its own conversation")
	# a line typed while the answer is still on its way is not sent twice
	await driver.settle()
	var calls_before: int = main.agent.calls_this_visit
	await driver.say("And one more thing.")
	driver.key(KEY_ENTER)
	driver.key(KEY_ENTER)
	driver.key(KEY_T, 116)
	check(not main.dialogue.input_open, "while the patient is answering the typing line stays shut")
	await driver.until(func() -> bool: return not main._thinking and not main._lock, 20.0)
	check(main.agent.calls_this_visit == calls_before + 1, "one sentence, one call, however many times ENTER is pressed")


## While the patient is still answering (the slow server replies after the game's own deadline),
## looking, the stamp and the call line do not wait for the answer and do not cancel it; a
## decision made then drops the answer that is still on its way (student request, November 15).
func meanwhile(main: MainScript, driver: PlayDriver) -> void:
	await driver.settle()
	check(main.agent.calls_this_visit + 2 <= main.agent.max_calls, "meanwhile: two calls are left in this visit")
	client.base_url = str(urls.slow)
	var fallbacks: int = main.agent.fallbacks_this_visit
	var seq: int = main._seq
	main.act_say("Take your time with this one.")
	check(main._thinking and main._seq == seq + 1, "meanwhile: the slow patient is thinking")
	await driver.seconds(0.4)
	check(main.rig != null and main.rig.thinking and main.rig._bubble.visible,
		"meanwhile: the patient is seen thinking, with the thought bubble by the head")
	var seen_before: bool = main.visit.seen.has("look:hands")
	main.act_look("hands")
	check(main._thinking and main._seq == seq + 1, "meanwhile: a look does not cancel the answer on its way")
	check(not main.visit.seen.has("look:hands") and main.desk.pulse == "grip", "meanwhile: the look happens and is shown (seen before: %s)" % seen_before)
	check(not main.visit.row_seen("hands"), "meanwhile: the thinking dots stay away while the look is read")
	check(await driver.until(func() -> bool: return not main._thinking and not main._lock, 20.0), "meanwhile: the answer still arrives after the look")
	check(main.agent.fallbacks_this_visit == fallbacks + 1 and main.dialogue.speaker == main._patient_name(),
		"meanwhile: it is the patient's line (the authored one: this server is slower than the deadline)")
	await driver.settle()
	var finished_record := main.visit.record
	main.act_say("One more question, then.")
	check(main._thinking, "meanwhile: thinking again")
	main.act_pick_stamp("treat")
	check(main._held == "treat" and main._thinking, "meanwhile: the TREAT stamp can be picked up while they answer")
	main.act_call_team()
	check(main._call_armed > 0.0 and main._held == "" and main._thinking, "meanwhile: so can the call line be opened (the stamp goes back)")
	main.act_call_team()
	check(not main._thinking and not main._lock and main.state != MainScript.State.EXAM, "meanwhile: the second press decides without waiting")
	var dropped := 0
	for rec in main.event_log.memory:
		if str(rec.get("type", "")) == "reply_dropped":
			dropped += 1
	check(dropped == 1, "meanwhile: the dropped answer is logged once, by stage, without words")
	# this is the third patient of the listed order, Vale, and a call turns him. A blow that
	# lands would end the night with no slip (student, November 18), so the shutter stops him.
	check(str(main.visit.case_data.get("id", "")) == "vale" and main.state == MainScript.State.ATTACK
		and main.visit.attack_cause == "refer", "meanwhile: the call turns Vale, as it always does")
	check(await driver.wait_for_telegraph(), "meanwhile: he gives his warning")
	driver.shutter_key()
	check(main.visit.outcome == "caught", "meanwhile: the shutter stops him")
	var slipped: bool = await driver.wait_for_slip(40.0)
	if not slipped:
		# say where it stopped: the state and the last events of the visit
		var last := PackedStringArray()
		for rec in main.event_log.memory.slice(-8):
			last.append(str(rec.get("type", "")))
		print("meanwhile: stopped in state %d, last events: %s" % [main.state, ", ".join(last)])
	check(slipped, "meanwhile: the visit ends with a slip")
	check(main.agent.record == null and finished_record.entries.is_empty(), "a resolved visit releases its record and drops late replies")
	client.base_url = str(urls.normal)


## Test the actual SETTINGS inputs against HTTP and wait for their visible result in both languages.
func test_patient_settings(main: MainScript, driver: PlayDriver) -> void:
	main.act_menu("settings")
	main.screens.settings_row = main.screens.SETTING_ROWS.find("patient_ai")
	for language in ["zh", "en"]:
		main.act_language(language)
		for pair in [["disabled", "disabled"], ["protocol", "version"], ["outdated", "version"], ["missing", "version"],
				["duplicate", "version"], ["late", "unreachable"], ["text", "mock"]]:
			main.agent_url = str(urls.health) + "/" + str(pair[0])
			main.model_client.base_url = main.agent_url
			driver.click(main.screens.setting_rects()["patient_ai:on"].get_center())
			check(main.screens.setting_hint() == main.screens.PATIENT_HINTS.checking, "SETTINGS shows the pending connection")
			await main.patient_check_finished
			var connected: bool = pair[1] == "mock"
			check(main.use_model == connected and main.screens.settings.patient_ai == ("on" if connected else "off")
				and main.screens.setting_hint() == main.screens.PATIENT_HINTS[pair[1]], "SETTINGS resolves " + str(pair[0]) + " in " + language)
		check(not main.screens.voice, "a text-only service offers typing")
		driver.click(main.screens.setting_rects()["patient_ai:off"].get_center())
	main.agent_url = str(urls.health) + "/delayed"
	main.model_client.base_url = main.agent_url
	main.act_setting("patient_ai", "on")
	main.act_setting("patient_ai", "off")
	await create_timer(0.35, true, false, true).timeout
	check(not main.use_model and main.screens.settings.patient_ai == "off", "an old health response cannot undo OFF")
	main.agent_url = str(urls.normal)
	main.model_client.base_url = main.agent_url
	main.mic.simulated = true
	driver.key(KEY_RIGHT)
	await main.patient_check_finished
	check(main.use_model and main.screens.voice and main.screens.status_line == main.STATUS_AI_VOICE,
		"the mock connects by keyboard and the title offers its voice route")
	main.act_menu_back()


## Play both languages through the real text box, network classifier, ASK and PRESS.
func test_optional_turns() -> void:
	var main: MainScript = load("res://scenes/main.tscn").instantiate()
	main.authored_order = true
	main.surprises_enabled = false
	root.add_child(main)
	await process_frame
	var driver := PlayDriver.new(self, main)
	check(await driver.open_counter() and await driver.buzz_in(), "a visit opens before its optional turns")
	await driver.settle()
	main.agent.client = client
	main.agent.run_id = "scene-beats"
	main.agent.set_mode("model")
	main._service_has_beats = true
	var before: Dictionary = main.visit.snapshot()
	var draws: int = main._snap_rng.state
	var memory := main.agent.record.entries.duplicate(true)
	client.base_url = str(urls.stt_slow) # replies successfully after 700 ms of wall time
	main._try_beat("arrive")
	check(main._beat_pending and not main._lock and not main._thinking, "an outstanding beat never owns the action lock")
	main.act_say_open()
	check(main.dialogue.input_open, "the doctor can type immediately during a slow beat")
	var deadline := Time.get_ticks_msec() + 6000
	while main._beat_pending and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not main._beat_pending, "the slow request resolves")
	check(main.agent.record.entries == memory and main.dialogue.input_open, "a late reply neither replaces the input nor enters memory")
	main.act_cancel()
	await driver.settle()
	client.base_url = str(urls.normal)
	main._try_beat("after_check","penlight")
	check(await driver.until(func()->bool: return not main._beat_pending, 12.0), "a timely optional turn resolves")
	check(main.agent.record.entries.size() == memory.size()+1, "a timely reply appears in the visit")
	check(main.visit.snapshot() == before and main._snap_rng.state == draws, "a spoken beat leaves the simulation unchanged")
	await driver.leave()


func test_visit_timeline() -> void:
	var main: MainScript = load("res://scenes/main.tscn").instantiate()
	main.beats_enabled = false
	main.authored_order = true
	main.surprises_enabled = false
	root.add_child(main)
	await process_frame
	var d := PlayDriver.new(self, main)
	check(await d.open_counter() and await d.buzz_in(), "the visit timeline opens at the counter")
	check(await d.until(func()->bool: return main._beat_opening_done, 16.0), "the timeline records the opening as it plays")
	main.agent.client = client
	main.agent.run_id = "btc-visit-record"
	main.agent.set_mode("model")
	client.base_url = str(urls.normal)
	check(await d.request_tool("grip") == "open", "the doctor opens the grip gauge")
	await d.put_away()
	check(not main.visit.record.entries.has({"role":"action","text":"done:grip"}), "putting the gauge away records no completed test")
	check(await d.request_tool("grip") == "open" and await d.squeeze_and_release(), "the doctor reopens and completes GRIP")
	await d.put_away()
	await d.settle()
	await d.press()
	check(await d.until(func()->bool: return main.visit.press_count == 1 and not main._lock and not main._thinking, 14.0), "an explicit PRESS follows the gauge reading")
	await d.settle()
	await d.say("Hello again.")
	check(await d.until(func()->bool: return main.agent.calls_this_visit == 3 and not main._lock and not main._thinking, 14.0), "a later line goes through the service with the visit's events")
	var performed: Array = main.event_log.memory.filter(func(e: Dictionary)->bool: return e.type in ["visit_start","scope_open","check_done","press","say"])
	check(performed.size() >= 6 and performed.all(func(e: Dictionary)->bool: return e.get("visit_id") == main.agent.visit_id), "anonymous game events and the patient share the appointment id")
	await d.leave()


func test_talk_rules(language: String) -> void:
	Lang.pin(language)
	var main: MainScript = load("res://scenes/main.tscn").instantiate()
	main.beats_enabled = false # foreground wire fixtures count each requested exchange
	main.authored_order = true
	main.surprises_enabled = false
	root.add_child(main)
	await process_frame
	var d := PlayDriver.new(self, main)
	check(await d.open_counter() and await d.buzz_in(), "bilingual talk visit begins")
	await d.settle()
	client.base_url = str(urls.normal)
	main.agent.client = client
	main.agent.run_id = "btc-fair-" + language
	main.agent.set_mode("model")
	var v := main.visit
	var p := v.patience
	var draws := main._snap_rng.state
	var actions := v.actions
	var quiet := "Lovely music." if language == "en" else "音乐真好听。"
	await d.say(quiet)
	check(await d.until(func()->bool: return main.agent.calls_this_visit == 1 and not main._lock and not main._thinking, 14.0), "the classifier and small-talk reply finish")
	check([v.patience, v.actions, main._snap_rng.state, v.asked, v.notes.speech, v.notes.temper] == [p, actions, draws, {}, [], []], "small talk spends no lamp, evidence or random draw")
	await d.settle()
	await d.say("How have you slept?" if language == "en" else "昨晚睡得好吗？")
	check(not main.dialogue.has_menu(), "the free question needs no price confirmation")
	check(await d.until(func()->bool: return v.answered.has("sleep"), 14.0), "confirming the typed sleep question joins the real ASK path")
	check(v.patience == p and v.actions == actions and main.agent.calls_this_visit == 1, "typed ASK uses no lamp or surprise roll without a dialogue call")
	check(v.notes.speech.size() == 1 and v.notes.temper.is_empty() and main._base_hint.contains(Lang.t(str(v.topic("sleep").q))), "one speech note and the matched question are visible")
	await d.settle()
	d.key(KEY_T, 116)
	var challenge := "Say it clearly." if language == "en" else "说清楚。"
	d.type_text(challenge)
	main.key_down(KEY_ENTER, 0, true)
	check(await d.until(func()->bool: return main.agent.calls_this_visit == 2 and not main._thinking, 14.0), "modified ENTER is ordinary speech")
	check(v.press_count == 0 and v.patience == p and v.notes.temper.is_empty(), "typed pressure cannot change exam state")
	await d.settle()
	await d.press()
	check(v.press_count == 1 and v.patience == p - 1, "only the button pushes")
	await d.settle()
	await d.press()
	check(v.outcome == "walkout", "accepting the warning ends a steady visit")
	await d.leave()


## Both launcher demos use the actual startup options and patient scene.
func test_launcher(mode: String) -> void:
	await process_frame
	var main: MainScript = load("res://scenes/main.tscn").instantiate()
	main.beats_enabled = false # foreground wire fixtures count each requested exchange
	root.add_child(main)
	var driver := PlayDriver.new(self, main)
	if main._patient_status == "checking":
		await main.patient_check_finished
	check(main.use_model and main._service_is_mock and main._patient_override == "on", "launcher connected to its mock service")
	if not main.use_model or not main._service_is_mock:
		await driver.leave()
		quit(1)
		return
	Engine.time_scale = 4.0
	check(await driver.open_counter() and await driver.buzz_in(), "launcher visit begins")
	await driver.settle()
	Engine.time_scale = 1.0
	var started := Time.get_ticks_msec()
	driver.key(KEY_T, 116)
	driver.type_text("Can we talk about my shift?")
	main.key_down(KEY_ENTER, 0, true)
	var label := "OFFLINE FALLBACK" if mode == "timeout" else "MOCK TRANSPORT"
	var source := "fallback" if mode == "timeout" else "model"
	check(await driver.until(func() -> bool:
		return main.agent.last.get("source") == source and main.clinic.corner_text.contains(label), 5.0), "corner shows reply source")
	var elapsed := Time.get_ticks_msec() - started
	check(elapsed < main.model_client.timeout_ms and main.agent.calls_this_visit == 1, "one bounded attempt")
	if mode == "timeout":
		check(main.agent.last.get("fallback_reason") == "http_504:upstream_timeout", "proxy deadline triggers the scripted reply")
		check(await driver.until(func() -> bool: return main._base_hint.contains("upstream_timeout") and main.dialogue.speaker == main._patient_name(), 2.0), "scripted reply and timeout reason are visible")
	else:
		check(await driver.until(func() -> bool: return " ".join(main.dialogue.lines) == NOVEL, 8.0),
			"generated mock line is displayed")
	print("LAUNCH mode=%s source=%s label_ms=%d calls=%d" % [mode, source, elapsed, main.agent.calls_this_visit])
	Engine.time_scale = 4.0
	await driver.settle()
	await driver.stamp("treat")
	check(await driver.wait_for_slip(), "launcher visit reaches its slip")
	await driver.leave()
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)


func test_scene() -> void:
	Engine.time_scale = 4.0
	var main: MainScript = load("res://scenes/main.tscn").instantiate()
	main.beats_enabled = false # foreground wire fixtures count each requested exchange
	main.authored_order = true      # the checks below follow the listed order of patients
	root.add_child(main)
	await process_frame
	main.audio.set_muted(true)
	main.mic.simulated = true      # an automated run never opens a microphone
	var driver := PlayDriver.new(self, main)
	await test_patient_settings(main, driver)
	check(await driver.open_counter(), "scene opens")
	check(await driver.buzz_in(), "patient arrives")
	check(main.agent.mode == "model" and main.agent.client == main.model_client, "the SETTINGS selection reaches the new visit")
	# The failure scenarios later in this scene change this client\'s base address.
	main.agent.client = client
	main.event_log.write("automated_run", {"runner":"autonomous-http-scene"})
	await driver.settle()
	main.act_ask("why")
	check(await driver.until(func() -> bool: return main.visit.answered.has("why") and main.dialogue.speaker == main._patient_name(), 20.0), "ASK displays the authored answer in the real scene")
	check(JSON.stringify(main.visit.notes.speech).contains(str(main.visit.topic("why").a)), "record stores the spoken authored answer")
	check(main.agent.calls_this_visit == 0 and main.visit.notes.temper.is_empty(), "authored ASK consumes no dialogue call or TEMPER note")
	await driver.settle()
	main.act_say("Nice music.")
	check(await driver.until(func() -> bool: return main.agent.calls_this_visit == 1 and not main._lock and not main._thinking, 20.0), "conversation reaches the model pipeline")
	await driver.settle()
	main.act_press()
	check(await driver.until(func() -> bool: return main.visit.press_count == 1 and not main._lock and not main._thinking, 20.0), "pressure uses same model pipeline")
	await driver.settle()
	main.act_say("Could you explain why you pulled your hand away?")
	check(await driver.until(func() -> bool: return main.agent.calls_this_visit == 3 and not main._thinking and not main._lock, 20.0), "free player text reaches dialogue")
	check(main.agent.calls_this_visit == 3, "only the three generated replies call the model")
	check(main.agent.fallbacks_this_visit == 0, "successful UI interactions do not fall back")
	await typed_conversation(main, driver)
	await spoken_conversation(main, driver)
	await meanwhile(main, driver)
	await driver.leave()
