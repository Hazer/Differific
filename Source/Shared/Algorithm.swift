import Foundation

class Algorithm {
  enum Counter {
    case zero, one, many

    func increment() -> Counter {
      switch self {
      case .zero:
        return .one
      case .one:
        return .many
      case .many:
        return self
      }
    }
  }

  class TableEntry: Equatable {
    var oldCounter: Counter = .zero
    var newCounter: Counter = .zero
    var indexesInOld: [Int] = []

    static func ==(lhs: TableEntry, rhs: TableEntry) -> Bool {
      return lhs.oldCounter == rhs.oldCounter && lhs.newCounter == rhs.newCounter && lhs.indexesInOld == rhs.indexesInOld
    }
  }

  enum ArrayEntry: Equatable {
    case tableEntry(TableEntry)
    case indexInOther(Int)

    public static func == (lhs: ArrayEntry, rhs: ArrayEntry) -> Bool {
      switch (lhs, rhs) {
      case (.tableEntry(let l), .tableEntry(let r)):
        return l == r
      case (.indexInOther(let l), .indexInOther(let r)):
        return l == r
      default:
        return false
      }
    }
  }

  public init() {}

  public func diff<T: Hashable>(old: [T], new: [T]) -> [Change<T>] {
    var table: [Int: TableEntry] = [:]
    var oldArray = [ArrayEntry]()
    var newArray = [ArrayEntry]()

    for item in new {
      let entry = table[item.hashValue] ?? TableEntry()
      entry.newCounter = entry.newCounter.increment()
      newArray.append(.tableEntry(entry))
      table[item.hashValue] = entry
    }

    for (offset, element) in old.enumerated() {
      let entry = table[element.hashValue] ?? TableEntry()
      entry.oldCounter = entry.oldCounter.increment()
      entry.indexesInOld.append(offset)
      oldArray.append(.tableEntry(entry))
      table[element.hashValue] = entry
    }

    newArray.enumerated().forEach { (indexOfNew, item) in
      switch item {
      case .tableEntry(let entry):
        guard !entry.indexesInOld.isEmpty else {
          return
        }
        let indexOfOld = entry.indexesInOld.removeFirst()
        let isObservation1 = entry.newCounter == .one && entry.oldCounter == .one
        let isObservation2 = entry.newCounter != .zero && entry.oldCounter != .zero && newArray[indexOfNew] == oldArray[indexOfOld]
        if isObservation1 || isObservation2 {
          newArray[indexOfNew] = .indexInOther(indexOfOld)
          oldArray[indexOfOld] = .indexInOther(indexOfNew)
        }
      case .indexInOther(_):
        break
      }
    }

    var changes = [Change<T>]()
    var deleteOffsets = Array(repeating: 0, count: old.count)
    var runningOffset = 0

    // Handle deletions

    var runningDeleteOffset = 0

    oldArray.enumerated().forEach { oldTuple in
      deleteOffsets[oldTuple.offset] = runningDeleteOffset

      guard case .tableEntry = oldTuple.element else {
        return
      }

      changes.append(Change(.delete,
                            item: old[oldTuple.offset],
                            index: oldTuple.offset))

      runningDeleteOffset += 1
    }

    // Handle insert, updates and move.

    for (offset, element) in newArray.enumerated() {
      switch element {
      case .tableEntry:
        runningOffset += 1

        changes.append(
          Change(.insert,
                 item: new[offset],
                 index: offset)
        )
      case .indexInOther(let oldIndex):
        if old[oldIndex] != new[offset] {
          changes.append(
            Change(.replace,
                   item: old[oldIndex],
                   index: oldIndex,
                   newIndex: offset,
                   newItem: new[offset])
          )
        }

        let deleteOffset = deleteOffsets[oldIndex]
        if (oldIndex - deleteOffset + runningOffset) != offset {
          changes.append(
            Change(.move,
                   item: new[offset],
                   index: oldIndex,
                   newIndex: offset)
          )
        }
      }
    }

    return changes
  }
}