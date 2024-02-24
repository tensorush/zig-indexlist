const std = @import("std");

pub const Index = struct {
    generation: usize = 0,
    idx: usize = 0,
};

pub fn IndexList(comptime T: type) type {
    return struct {
        const Self = @This();

        const Entry = union(enum) {
            occupied: Occupied,
            next_free: ?usize,
        };

        const Occupied = struct {
            generation: usize = 0,
            next: ?usize = null,
            prev: ?usize = null,
            item: T,
        };

        const Iterator = struct {
            list: *const Self,
            next_idx: ?usize,

            fn next(self: *Iterator) ?T {
                const next_idx = self.next_idx orelse return null;
                const entry = &self.list.entries.items[next_idx];
                self.next_idx = entry.occupied.next;
                return entry.occupied.item;
            }
        };

        entries: std.ArrayList(Entry),
        next_free: ?usize = null,
        generation: usize = 0,
        head: ?usize = null,
        tail: ?usize = null,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .entries = std.ArrayList(Entry).init(allocator) };
        }

        pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !Self {
            return .{ .entries = try std.ArrayList(Entry).initCapacity(allocator, capacity) };
        }

        pub fn deinit(self: Self) void {
            self.entries.deinit();
        }

        pub fn get(self: Self, index: Index) ?T {
            if (index.idx < self.entries.items.len) {
                return switch (self.entries.items[index.idx]) {
                    .occupied => |entry| if (entry.generation == index.generation) entry.item else null,
                    .next_free => null,
                };
            } else {
                return null;
            }
        }

        pub fn getHead(self: Self) ?T {
            return switch (self.entries.items[self.head orelse return null]) {
                .occupied => |entry| entry.item,
                .next_free => null,
            };
        }

        pub fn getHeadIndex(self: Self) ?Index {
            const idx = self.head orelse return null;
            return switch (self.entries.items[idx]) {
                .occupied => |entry| .{ .idx = idx, .generation = entry.generation },
                .next_free => null,
            };
        }

        pub fn getTailIndex(self: Self) ?Index {
            const idx = self.tail orelse return null;
            return switch (self.entries.items[idx]) {
                .occupied => |entry| .{ .idx = idx, .generation = entry.generation },
                .next_free => null,
            };
        }

        pub fn contains(self: *const Self, value: T) bool {
            var iter = self.iterator();
            while (iter.next()) |item| {
                if (item == value) {
                    return true;
                }
            }
            return false;
        }

        pub fn iterator(self: *const Self) Iterator {
            return .{ .list = self, .next_idx = self.head };
        }

        pub fn pushBack(self: *Self, item: T) !Index {
            if (self.head == null) {
                const generation = self.generation;
                const idx = blk: {
                    if (self.next_free) |idx| {
                        self.next_free = self.entries.items[idx].next_free;
                        self.entries.items[idx] = .{ .occupied = .{ .item = item, .generation = generation } };
                        break :blk idx;
                    } else {
                        const idx = self.entries.items.len;
                        try self.entries.append(.{ .occupied = .{ .item = item, .generation = generation } });
                        break :blk idx;
                    }
                };
                self.tail = idx;
                self.head = idx;
                return .{ .idx = idx, .generation = generation };
            }

            const tail_idx = self.tail.?;
            const idx = blk: {
                if (self.next_free) |idx| {
                    self.next_free = self.entries.items[idx].next_free;
                    self.entries.items[idx] = .{ .occupied = .{ .item = item, .generation = self.generation, .prev = tail_idx } };
                    break :blk idx;
                } else {
                    const idx = self.entries.items.len;
                    try self.entries.append(.{ .occupied = .{ .item = item, .generation = self.generation, .prev = tail_idx } });
                    break :blk idx;
                }
            };

            self.entries.items[tail_idx].occupied.next = idx;
            self.tail = idx;
            return .{ .idx = idx, .generation = self.generation };
        }

        pub fn pushFront(self: *Self, item: T) !Index {
            if (self.head == null) {
                return try self.pushBack(item);
            }

            const head_idx = self.head.?;
            const idx = blk: {
                if (self.next_free) |idx| {
                    switch (self.entries.items[idx]) {
                        .next_free => |next_free| self.next_free = next_free,
                        .occupied => return error.UnexpectedOccupiedEntry,
                    }
                    self.entries.items[idx] = .{ .occupied = .{ .item = item, .generation = self.generation, .next = head_idx } };
                    break :blk idx;
                } else {
                    const idx = self.entries.items.len;
                    try self.entries.append(.{ .occupied = .{ .item = item, .generation = self.generation, .next = head_idx } });
                    break :blk idx;
                }
            };

            self.entries.items[head_idx].occupied.prev = idx;
            self.head = idx;
            return .{ .idx = idx, .generation = self.generation };
        }

        pub fn nextIndex(self: Self, index: Index) ?Index {
            if (index.idx < self.entries.items.len) {
                return switch (self.entries.items[index.idx]) {
                    .occupied => |entry| blk: {
                        if (entry.generation == index.generation) {
                            if (entry.next) |idx| {
                                if (idx < self.entries.items.len) {
                                    break :blk .{ .idx = idx, .generation = self.entries.items[idx].occupied.generation };
                                } else {
                                    break :blk null;
                                }
                            } else {
                                break :blk null;
                            }
                        } else {
                            break :blk null;
                        }
                    },
                    .next_free => null,
                };
            } else {
                return null;
            }
        }

        pub fn prevIndex(self: Self, index: Index) ?Index {
            if (index.idx < self.entries.items.len) {
                return switch (self.entries.items[index.idx]) {
                    .occupied => |entry| blk: {
                        if (entry.generation == index.generation) {
                            if (entry.prev) |idx| {
                                if (idx < self.entries.items.len) {
                                    break :blk .{ .idx = idx, .generation = self.entries.items[idx].occupied.generation };
                                } else {
                                    break :blk null;
                                }
                            } else {
                                break :blk null;
                            }
                        } else {
                            break :blk null;
                        }
                    },
                    .next_free => null,
                };
            } else {
                return null;
            }
        }

        pub fn remove(self: *Self, index: Index) ?T {
            const head_idx = self.head orelse return null;
            const tail_idx = self.tail orelse return null;

            var next_idx: ?usize = undefined;
            var prev_idx: ?usize = undefined;
            var idx: usize = undefined;
            if (index.idx < self.entries.items.len) {
                switch (self.entries.items[index.idx]) {
                    .occupied => |entry| {
                        if (index.generation != entry.generation) {
                            return null;
                        }
                        next_idx = entry.next;
                        prev_idx = entry.prev;
                        idx = index.idx;
                    },
                    .next_free => return null,
                }
            } else {
                return null;
            }

            const removed = self.entries.items[idx];
            self.entries.items[idx] = .{ .next_free = self.next_free };
            self.next_free = idx;
            self.generation += 1;

            if (idx == head_idx and idx == tail_idx) {
                self.head = null;
                self.tail = null;
            } else if (idx == head_idx) {
                self.entries.items[next_idx.?].occupied.prev = null;
                self.head = next_idx;
            } else if (idx == tail_idx) {
                self.entries.items[prev_idx.?].occupied.next = null;
                self.tail = prev_idx;
            } else if (idx != head_idx and idx != tail_idx) {
                self.entries.items[next_idx.?].occupied.prev = prev_idx;
                self.entries.items[prev_idx.?].occupied.next = next_idx;
            }
            return removed.occupied.item;
        }

        pub fn insertBefore(self: *Self, index: Index, item: T) !?Index {
            var prev_idx: ?usize = undefined;
            var idx: usize = undefined;
            if (index.idx < self.entries.items.len) {
                switch (self.entries.items[index.idx]) {
                    .occupied => |entry| {
                        if (index.generation != entry.generation) {
                            return null;
                        }
                        prev_idx = entry.prev;
                        idx = index.idx;
                    },
                    .next_free => return null,
                }
            } else {
                return null;
            }

            const entry = Entry{ .occupied = .{ .item = item, .generation = self.generation, .next = idx, .prev = prev_idx } };
            const new_idx = blk: {
                if (self.next_free) |new_idx| {
                    self.next_free = self.entries.items[new_idx].next_free;
                    self.entries.items[new_idx] = entry;
                    break :blk new_idx;
                } else {
                    const new_idx = self.entries.items.len;
                    try self.entries.append(entry);
                    break :blk new_idx;
                }
            };

            self.entries.items[idx].occupied.prev = new_idx;
            if (prev_idx) |prev| {
                self.entries.items[prev].occupied.next = new_idx;
            } else {
                self.head = new_idx;
            }

            return .{ .idx = new_idx, .generation = self.generation };
        }

        pub fn insertAfter(self: *Self, index: Index, item: T) !?Index {
            var next_idx: ?usize = undefined;
            var idx: usize = undefined;
            if (index.idx < self.entries.items.len) {
                switch (self.entries.items[index.idx]) {
                    .occupied => |entry| {
                        if (index.generation != entry.generation) {
                            return null;
                        }
                        next_idx = entry.next;
                        idx = index.idx;
                    },
                    .next_free => return null,
                }
            } else {
                return null;
            }

            const entry = Entry{ .occupied = .{ .item = item, .generation = self.generation, .next = next_idx, .prev = idx } };
            const new_idx = blk: {
                if (self.next_free) |new_idx| {
                    self.next_free = self.entries.items[new_idx].next_free;
                    self.entries.items[new_idx] = entry;
                    break :blk new_idx;
                } else {
                    const new_idx = self.entries.items.len;
                    try self.entries.append(entry);
                    break :blk new_idx;
                }
            };

            self.entries.items[idx].occupied.next = new_idx;
            if (next_idx) |next| {
                self.entries.items[next].occupied.prev = new_idx;
            } else {
                self.tail = new_idx;
            }

            return .{ .idx = new_idx, .generation = self.generation };
        }

        pub fn indexOf(self: Self, item: T) ?Index {
            var next = self.head;
            while (next) |idx| {
                const entry = &self.entries.items[idx].occupied;
                if (entry.item == item) {
                    return .{ .idx = idx, .generation = entry.generation };
                } else {
                    next = entry.next;
                }
            }
            return null;
        }

        pub fn popFront(self: *Self) ?T {
            const head_idx = self.head orelse return null;

            const next_idx = switch (self.entries.items[head_idx]) {
                .occupied => |entry| entry.next,
                .next_free => return null,
            };

            const removed = self.entries.items[head_idx];
            self.entries.items[head_idx] = .{ .next_free = self.next_free };
            self.next_free = head_idx;
            self.generation += 1;

            if (head_idx == self.tail) {
                self.head = null;
                self.tail = null;
            } else {
                self.entries.items[next_idx.?].occupied.prev = null;
                self.head = next_idx;
            }

            return removed.occupied.item;
        }

        test "pushBack" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            try std.testing.expectEqual(list.entries.items[0].occupied, Occupied{ .item = 5 });
        }

        test "contains" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            try std.testing.expect(list.contains(5));
        }

        test "get" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const five = try list.pushBack(5);
            var entry = list.get(five).?;
            entry += 1;
            const six = try list.pushBack(entry);

            try std.testing.expectEqual(list.get(six).?, 6);
        }

        test "nextIndex" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const five = try list.pushBack(5);
            _ = try list.pushBack(10);
            const ten_index = list.nextIndex(five).?;

            try std.testing.expectEqual(list.get(ten_index).?, 10);
            try std.testing.expectEqual(null, list.nextIndex(ten_index));
        }

        test "prevIndex" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            const ten = try list.pushBack(10);
            const five_index = list.prevIndex(ten).?;

            try std.testing.expectEqual(list.get(five_index).?, 5);
            try std.testing.expectEqual(null, list.prevIndex(five_index));
        }

        test "pushBack_thrice" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            _ = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .occupied = .{ .item = 5, .next = 1 } },
                .{ .occupied = .{ .item = 10, .next = 2, .prev = 0 } },
                .{ .occupied = .{ .item = 15, .prev = 1 } },
            });
        }

        test "remove_middle" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            const ten = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.remove(ten).?, 10);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .occupied = .{ .item = 5, .next = 2 } },
                .{ .next_free = null },
                .{ .occupied = .{ .item = 15, .prev = 0 } },
            });
            try std.testing.expectEqual(list.generation, 1);
            try std.testing.expectEqual(list.next_free, 1);
            try std.testing.expectEqual(list.head, 0);
            try std.testing.expectEqual(list.tail, 2);
        }

        test "remove_head" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const five = try list.pushBack(5);
            _ = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.remove(five).?, 5);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .next_free = null },
                .{ .occupied = .{ .item = 10, .next = 2 } },
                .{ .occupied = .{ .item = 15, .prev = 1 } },
            });
            try std.testing.expectEqual(list.generation, 1);
            try std.testing.expectEqual(list.next_free, 0);
            try std.testing.expectEqual(list.head, 1);
            try std.testing.expectEqual(list.tail, 2);
        }

        test "remove_tail" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            _ = try list.pushBack(10);
            const fifteen = try list.pushBack(15);

            try std.testing.expectEqual(list.remove(fifteen).?, 15);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .occupied = .{ .item = 5, .next = 1 } },
                .{ .occupied = .{ .item = 10, .prev = 0 } },
                .{ .next_free = null },
            });
            try std.testing.expectEqual(list.generation, 1);
            try std.testing.expectEqual(list.next_free, 2);
            try std.testing.expectEqual(list.head, 0);
            try std.testing.expectEqual(list.tail, 1);
        }

        test "remove_only" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const five = try list.pushBack(5);

            try std.testing.expectEqual(list.remove(five).?, 5);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{.{ .next_free = null }});
            try std.testing.expectEqual(list.generation, 1);
            try std.testing.expectEqual(list.next_free, 0);
            try std.testing.expectEqual(list.head, null);
            try std.testing.expectEqual(list.tail, null);
        }

        test "remove_null" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const five_index = try list.pushBack(5);
            const five_entry = list.remove(five_index).?;

            try std.testing.expectEqual(list.entries.items[0], Entry{ .next_free = null });
            try std.testing.expectEqual(five_entry, 5);
            try std.testing.expectEqual(list.remove(five_index), null);
        }

        test "iterator" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            const ten = try list.pushBack(10);
            _ = try list.pushBack(15);
            _ = list.remove(ten);

            var iter = list.iterator();
            try std.testing.expectEqual(iter.next().?, 5);
            try std.testing.expectEqual(iter.next().?, 15);
            try std.testing.expectEqual(iter.next(), null);
        }

        test "reallocation" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            const ten = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.remove(ten).?, 10);

            _ = try list.pushBack(20);

            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .occupied = .{ .item = 5, .next = 2 } },
                .{ .occupied = .{ .item = 20, .prev = 2, .generation = 1 } },
                .{ .occupied = .{ .item = 15, .next = 1, .prev = 0 } },
            });
        }

        test "generations" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const five = try list.pushBack(5);
            const ten = try list.pushBack(10);
            _ = try list.pushBack(15);
            _ = list.remove(ten);
            const twenty = try list.pushBack(20);

            try std.testing.expectEqual(list.get(five), 5);
            try std.testing.expectEqual(list.get(ten), null);
            try std.testing.expectEqual(list.get(twenty), 20);
        }

        test "getHead" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            try std.testing.expectEqual(list.getHead(), null);

            const five = try list.pushBack(5);

            try std.testing.expectEqual(list.getHead().?, 5);

            _ = try list.pushBack(10);
            _ = list.remove(five);

            try std.testing.expectEqual(list.getHead().?, 10);
            try std.testing.expectEqual(list.head, 1);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .next_free = null },
                .{ .occupied = .{ .item = 10 } },
            });
        }

        test "getHeadIndex" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            try std.testing.expectEqual(list.getHeadIndex(), null);

            const five = try list.pushBack(5);

            try std.testing.expectEqual(list.getHeadIndex().?, five);
        }

        test "getTailIndex" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            try std.testing.expectEqual(list.getTailIndex(), null);

            _ = try list.pushBack(5);
            const ten = try list.pushBack(10);

            try std.testing.expectEqual(list.getTailIndex().?, ten);
        }

        test "pushFront" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushFront(5);
            _ = try list.pushFront(10);
            _ = try list.pushFront(15);

            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .occupied = .{ .item = 5, .prev = 1 } },
                .{ .occupied = .{ .item = 10, .next = 0, .prev = 2 } },
                .{ .occupied = .{ .item = 15, .next = 1 } },
            });
        }

        test "indexOf" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            _ = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.indexOf(10).?, Index{ .idx = 1, .generation = 0 });
            try std.testing.expectEqual(list.indexOf(20), null);
        }

        test "indexOf_correct_generation" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            const ten = try list.pushBack(10);
            _ = list.remove(ten);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.indexOf(5).?, Index{});
        }

        test "indexOf_first_occurrence" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(3);
            const six = try list.pushBack(6);
            const first_nine = try list.pushBack(9);
            _ = try list.pushBack(12);
            _ = list.remove(six);
            _ = try list.pushBack(9);

            try std.testing.expectEqual(list.indexOf(9).?, first_nine);
        }

        test "popFront" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            _ = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.popFront().?, 5);
            try std.testing.expectEqual(list.popFront().?, 10);
            try std.testing.expectEqual(list.popFront().?, 15);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .next_free = null },
                .{ .next_free = 0 },
                .{ .next_free = 1 },
            });
            try std.testing.expectEqual(list.generation, 3);
            try std.testing.expectEqual(list.next_free, 2);
            try std.testing.expectEqual(list.head, null);
            try std.testing.expectEqual(list.tail, null);
        }

        test "pushBack_and_popFront" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushBack(5);
            _ = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.popFront().?, 5);
            try std.testing.expectEqual(list.popFront().?, 10);
            try std.testing.expectEqual(list.popFront().?, 15);

            _ = try list.pushBack(5);
            _ = try list.pushBack(10);
            _ = try list.pushBack(15);

            try std.testing.expectEqual(list.popFront().?, 5);
            try std.testing.expectEqual(list.popFront().?, 10);
            try std.testing.expectEqual(list.popFront().?, 15);
            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .next_free = 1 },
                .{ .next_free = 2 },
                .{ .next_free = null },
            });
            try std.testing.expectEqual(list.generation, 6);
            try std.testing.expectEqual(list.next_free, 0);
            try std.testing.expectEqual(list.head, null);
            try std.testing.expectEqual(list.tail, null);
        }

        test "pushFront_next_free" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            _ = try list.pushFront(0);
            _ = try list.pushFront(73);
            _ = list.popFront();
            _ = try list.pushFront(1);
            _ = try list.pushFront(2);

            try std.testing.expectEqualSlices(Entry, list.entries.items, &.{
                .{ .occupied = .{ .item = 0, .prev = 1 } },
                .{ .occupied = .{ .item = 1, .next = 0, .prev = 2, .generation = 1 } },
                .{ .occupied = .{ .item = 2, .next = 1, .generation = 1 } },
            });
            try std.testing.expectEqual(list.next_free, null);
            try std.testing.expectEqual(list.generation, 1);
            try std.testing.expectEqual(list.head, 2);
            try std.testing.expectEqual(list.tail, 0);
        }

        test "insertBefore" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const index = try list.pushFront(2);
            _ = try list.insertBefore(index, 0);

            var iter = list.iterator();
            try std.testing.expectEqual(iter.next().?, 0);
            try std.testing.expectEqual(iter.next().?, 2);
            try std.testing.expectEqual(list.get(list.prevIndex(index).?).?, 0);

            _ = try list.insertBefore(index, 1);

            iter = list.iterator();
            try std.testing.expectEqual(iter.next().?, 0);
            try std.testing.expectEqual(iter.next().?, 1);
            try std.testing.expectEqual(iter.next().?, 2);
            try std.testing.expectEqual(list.get(list.prevIndex(index).?).?, 1);
        }

        test "insertAfter" {
            var list = Self.init(std.testing.allocator);
            defer list.deinit();

            const index = try list.pushFront(0);
            _ = try list.insertAfter(index, 2);

            var iter = list.iterator();

            try std.testing.expectEqual(iter.next().?, 0);
            try std.testing.expectEqual(iter.next().?, 2);
            try std.testing.expectEqual(list.get(list.nextIndex(index).?).?, 2);

            _ = try list.insertAfter(index, 1);

            iter = list.iterator();
            try std.testing.expectEqual(iter.next().?, 0);
            try std.testing.expectEqual(iter.next().?, 1);
            try std.testing.expectEqual(iter.next().?, 2);
            try std.testing.expectEqual(list.get(list.nextIndex(index).?).?, 1);
        }
    };
}

test {
    std.testing.refAllDecls(IndexList(u8));
}
