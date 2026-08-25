extends GutTest

## Official TRAPRUSH course ids used by matchmaking JSON.
## HTTP never accepts res:// paths or UGC documents.

const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")


func test_normalize_known_ids_and_reject_paths() -> void:
	assert_eq(OfficialCourses.DEFAULT_ID, "course_01")
	assert_true(OfficialCourses.is_id("course_01"))
	assert_true(OfficialCourses.is_id("course_02"))
	assert_true(OfficialCourses.is_id("course_03"))
	assert_eq(OfficialCourses.normalize_id("  course_02  "), "course_02")
	assert_eq(OfficialCourses.normalize_id(""), "")
	assert_eq(OfficialCourses.normalize_id("course_99"), "")
	assert_eq(OfficialCourses.normalize_id("res://content/official/traprush/course_01.json"), "")
	assert_eq(OfficialCourses.DEFAULT_SEATS, 2)
	assert_eq(OfficialCourses.normalize_seats(1), 1)
	assert_eq(OfficialCourses.normalize_seats(8), 8)
	assert_eq(OfficialCourses.normalize_seats(0), 0)
	assert_eq(OfficialCourses.normalize_seats(9), 0)
	assert_eq(
		OfficialCourses.document_path("course_03"),
		"res://content/official/traprush/course_03.json"
	)
	assert_eq(OfficialCourses.document_path("course_99"), "")
