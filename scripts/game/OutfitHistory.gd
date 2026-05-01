class_name OutfitHistory
extends RefCounted

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var max_size := 64


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func remember(snapshot: Dictionary) -> void:
	if not _undo_stack.is_empty() and _snapshot_signature(_undo_stack[_undo_stack.size() - 1]) == _snapshot_signature(snapshot):
		return
	_undo_stack.append(snapshot.duplicate(true))
	while _undo_stack.size() > max_size:
		_undo_stack.remove_at(0)
	_redo_stack.clear()


func undo(current_snapshot: Dictionary) -> Dictionary:
	if _undo_stack.is_empty():
		return {}
	_redo_stack.append(current_snapshot.duplicate(true))
	return _undo_stack.pop_back()


func redo(current_snapshot: Dictionary) -> Dictionary:
	if _redo_stack.is_empty():
		return {}
	_undo_stack.append(current_snapshot.duplicate(true))
	return _redo_stack.pop_back()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo_count() -> int:
	return _undo_stack.size()


func _snapshot_signature(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot)
