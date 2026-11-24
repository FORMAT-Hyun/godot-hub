class_name DownloadsPanel
extends VBoxContainer
## 사이드바 아래 다운로드 진행 상황

var _widgets := {}  # job id -> {bar, status}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	Downloads.jobs_changed.connect(_rebuild)
	Downloads.job_updated.connect(_on_job_updated)
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_widgets.clear()
	visible = not Downloads.jobs.is_empty()
	if not visible:
		return
	add_child(HubUI.label(L.t("다운로드"), "SectionLabel"))
	for job in Downloads.jobs:
		var panel := PanelContainer.new()
		panel.theme_type_variation = "RowPanel"
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		panel.add_child(vb)
		var top := HBoxContainer.new()
		vb.add_child(top)
		var title := HubUI.label(job.title)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size", 13)
		top.add_child(title)
		var active: bool = Downloads.ACTIVE_STATES.has(job.state)
		var x := HubUI.flat_icon_button("close", L.t("취소") if active else L.t("닫기"))
		x.disabled = job.state == "extracting"
		var id: int = job.id
		x.pressed.connect(func() -> void:
			if active:
				Downloads.cancel(id)
			else:
				Downloads.dismiss(id))
		top.add_child(x)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		bar.max_value = 100
		vb.add_child(bar)
		var status := HubUI.label("", "DimLabel")
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size.x = 160
		vb.add_child(status)
		_widgets[id] = {"bar": bar, "status": status}
		_on_job_updated(job)
		add_child(panel)


func _on_job_updated(job: Dictionary) -> void:
	if not _widgets.has(job.id):
		return
	var bar: ProgressBar = _widgets[job.id].bar
	var status: Label = _widgets[job.id].status
	# 크기를 모르면(progress < 0) 진행 막대를 '진행 중' 모양으로
	bar.indeterminate = str(job.state) == "downloading" and float(job.progress) < 0.0
	bar.value = maxf(float(job.progress), 0.0) * 100.0
	status.remove_theme_color_override("font_color")
	match str(job.state):
		"queued":
			status.text = L.t("대기 중")
		"downloading":
			if float(job.progress) < 0.0:
				status.text = HubUI.human_size(job.downloaded)
			else:
				status.text = "%d%%  ·  %s / %s" % [int(job.progress * 100), HubUI.human_size(job.downloaded), HubUI.human_size(job.size)]
		"extracting":
			status.text = L.t("압축 푸는 중 %d%%") % int(job.progress * 100)
		"done":
			status.text = L.t("설치 완료")
			status.add_theme_color_override("font_color", HubTheme.SUCCESS)
		"canceled":
			status.text = L.t("취소됨")
		"error":
			status.text = str(job.message)
			status.add_theme_color_override("font_color", HubTheme.ERROR)
