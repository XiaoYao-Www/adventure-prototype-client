class_name TestHelper
extends RefCounted
## 可重用的測試斷言輔助（headless，無外部框架）。
##
## 用法：
##   var th := TestHelper.new()
##   th.section("grid")
##   th.check(condition, "說明")
##   th.check_eq(actual, expected, "說明")
## 最後以 summary() 取得 "TESTS OK n/n" / "TESTS FAILED ..." 並由呼叫端 quit(code)。

var passed: int = 0
var failed: int = 0
var skipped: int = 0
var failures: Array[String] = []
var skip_notes: Array[String] = []


func section(title: String) -> void:
	print("")
	print("--- %s ---" % title)


## 基本斷言；回傳結果方便後續連鎖判斷。
func check(condition: bool, name: String) -> bool:
	if condition:
		passed += 1
		print("[PASS] %s" % name)
		return true
	failed += 1
	failures.append(name)
	print("[FAIL] %s" % name)
	return false


func check_true(condition: bool, name: String) -> bool:
	return check(condition, name)


func check_false(condition: bool, name: String) -> bool:
	return check(not condition, name)


func check_eq(actual: Variant, expected: Variant, name: String) -> bool:
	var ok: bool = actual == expected
	if ok:
		return check(true, name)
	failed += 1
	var detail: String = "%s（expected=%s, actual=%s）" % [name, _describe(expected), _describe(actual)]
	failures.append(detail)
	print("[FAIL] %s" % detail)
	return false


func check_ne(actual: Variant, unexpected: Variant, name: String) -> bool:
	return check(actual != unexpected, "%s（不應等於 %s）" % [name, _describe(unexpected)])


func check_contains(haystack: String, needle: String, name: String) -> bool:
	if haystack.contains(needle):
		return check(true, "%s（含 '%s'）" % [name, needle])
	failed += 1
	var detail: String = "%s（找不到 '%s'；實際內容前 400 字：%s）" % [name, needle, haystack.left(400)]
	failures.append(detail)
	print("[FAIL] %s" % detail)
	return false


func check_array_contains(values: Array, needle: Variant, name: String) -> bool:
	return check(values.has(needle), "%s（含 %s）" % [name, _describe(needle)])


func skip(name: String, reason: String) -> void:
	skipped += 1
	skip_notes.append("%s：%s" % [name, reason])
	print("[SKIP] %s（%s）" % [name, reason])


func summary() -> String:
	var total: int = passed + failed
	if failed == 0:
		return "TESTS OK %d/%d" % [passed, total]
	return "TESTS FAILED %d/%d（失敗 %d）" % [passed, total, failed]


func _describe(value: Variant) -> String:
	if value is String:
		return "\"" + value + "\""
	return str(value)
