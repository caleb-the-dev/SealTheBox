extends SceneTree

func _init() -> void:
    _test_initial_state()
    _test_seal_tab()
    _test_win_condition()
    _test_critical_win()
    _test_can_seal()
    print("TabBoard tests passed!")
    quit()

func _test_initial_state() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    assert(board.get_sum() == 45, "Initial sum should be 45, got %d" % board.get_sum())
    assert(board.get_remaining().size() == 9, "Should have 9 tabs")

func _test_seal_tab() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    board.seal_tab(5)
    assert(not 5 in board.get_remaining(), "Tab 5 should be sealed")
    assert(board.get_sum() == 40, "Sum after sealing 5 should be 40, got %d" % board.get_sum())
    assert(board.get_remaining().size() == 8, "Should have 8 tabs remaining")

func _test_win_condition() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    # Seal everything except 1,2,3 (sum=6) — below threshold 13
    for tab in [4, 5, 6, 7, 8, 9]:
        board.seal_tab(tab)
    assert(board.check_win(13), "Sum 6 should satisfy threshold 13")
    assert(not board.check_win(5), "Sum 6 should NOT satisfy threshold 5")
    assert(not board.check_critical_win(), "Tabs still remain, not critical win")
    # Threshold boundary: sum exactly 13 = win
    var board2 = TabBoard.new()
    board2.reset([4, 9])  # sum = 13
    assert(board2.check_win(13), "Sum exactly 13 should be a win (<=)")
    # sum 14 = not win
    var board3 = TabBoard.new()
    board3.reset([5, 9])  # sum = 14
    assert(not board3.check_win(13), "Sum 14 should NOT satisfy threshold 13")

func _test_critical_win() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3])
    board.seal_tab(1)
    board.seal_tab(2)
    board.seal_tab(3)
    assert(board.check_critical_win(), "All tabs sealed = critical win")
    assert(board.check_win(0), "Critical win also satisfies threshold 0")

func _test_can_seal() -> void:
    var board = TabBoard.new()
    board.reset([1, 2, 3, 4, 5, 6, 7, 8, 9])
    assert(board.can_seal([5], 5), "Single die 5 seals tab 5")
    assert(board.can_seal([3, 2], 5), "3+2=5 seals tab 5")
    assert(board.can_seal([1, 2, 3], 6), "1+2+3=6 seals tab 6")
    assert(not board.can_seal([3, 1], 5), "3+1=4 does not seal tab 5")
    assert(not board.can_seal([3, 2], 10), "Tab 10 not in range")
    board.seal_tab(5)
    assert(not board.can_seal([5], 5), "Cannot seal already-sealed tab 5")
