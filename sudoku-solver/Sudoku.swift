//
//  Sudoku.swift
//  sudoku-solver
//
//  Created by Patryk Scheffler on 6/19/18.
//  Copyright © 2018 Patryk Scheffler. All rights reserved.
//

import Foundation


public struct Mark {
    public let value: Int
    
    public init(_ value: Int) {
        assert(1 <= value && value <= 9, "only values 1...9 are valid for a mark")
        
        switch value {
        case 1...9: self.value = value
        default:    self.value = 1
        }
    }
}

/// A Sudoku square is empty or has a mark with value 1...9.
public enum Square: ExpressibleByIntegerLiteral {
    case Empty
    case Marked(Mark)
    
    /// Initialize a square value from an integer literal
    ///
    /// Any value in the range 1...9 will be treated as a mark.
    /// Any other value will result in an empty square.
    public init(integerLiteral value: IntegerLiteralType) {
        switch value {
        case 1...9: self = .Marked(Mark(value))
        default:    self = .Empty
        }
    }
    
    var isEmpty: Bool {
        switch self {
        case .Empty:   return true
        case .Marked(_): return false
        }
    }
    
    func isMarkedWithValue(value: Int) -> Bool {
        switch self {
        case .Empty:            return false
        case .Marked(let mark): return mark.value == value
        }
    }
    
    func returnValue() -> Int {
        switch self {
        case .Empty: return -1
        case .Marked(let mark): return mark.value
        }
    }
}

// A Sudoku puzzle is a 9x9 matrix of squares
public typealias Sudoku = [[Square]]

/// Find a solution for a sudoku puzzle
public func solveSudoku(s: Sudoku) -> Sudoku? {
    if let (row, col) = findEmptySquare(s: s) {
        for mark in 1...9 {
            if canTryMark(mark: mark, atRow: row, column: col, inSudoku: s) {
                let candidate = copySudoku(s: s, withMark: mark, atRow: row, column: col)
                if let solution = solveSudoku(s: candidate) {
                    return solution
                }
            }
        }
        
        // No solution
        return nil
    }
    else {
        // No empty squares, so it's solved
        return s
    }
}

/// Find all solutions for a sudoku puzzle, invoking a user-provided function for each solution.
///
/// If the user-provided function returns false, then iteration of solutions will stop.
public func findAllSolutions(s: Sudoku, processAndContinue: @escaping (Sudoku) -> Bool) {
    // This will be set true if processAndContinue() returns false
    var stop = false
    
    // Local functions can't refer to themselves, so to let findSolutionsUntilStop()
    // make a recursive call to itself, we need to have another local variable that
    // holds a reference to it.
    var recursiveCall: (Sudoku) -> () = { _ in return }
    
    // This is the same as solveSudoku(), except that it invokes processAndContinue()
    // when it finds a solution, and if that returns true, it keeps searching for
    // solutions.
    func findSolutionsUntilStop(s: Sudoku) {
        if let (row, col) = findEmptySquare(s: s) {
            for mark in 1...9 {
                if stop {
                    break
                }
                
                if canTryMark(mark: mark, atRow: row, column: col, inSudoku: s) {
                    let candidate = copySudoku(s: s, withMark: mark, atRow: row, column: col)
                    recursiveCall(candidate)
                }
            }
        }
        else {
            // No empty squares, so this is a solution
            if !processAndContinue(s) {
                stop = true
            }
        }
    }
    
    recursiveCall = findSolutionsUntilStop
    
    findSolutionsUntilStop(s: s)
}

/// Create a copy of a Sudoku with an additional mark
private func copySudoku(s: Sudoku, withMark mark: Int, atRow row: Int, column col: Int) -> Sudoku {
    var result = Sudoku(s)
    
    var newRow  = Array(s[row])
    newRow[col] = .Marked(Mark(mark))
    result[row] = newRow
    
    return result
}

/// Find an empty square in a Sudoku board
///
/// :returns: (row, column), or nil if there are no empty squares
private func findEmptySquare(s: Sudoku) -> (Int, Int)? {
    for row in 0..<9 { for col in 0..<9 {
        if s[row][col].isEmpty { return (row, col) }
        }}
    return nil
}

/// Determine whether putting the specified mark at the specified square would violate uniqueness constrains
private func canTryMark(mark: Int, atRow row: Int, column col: Int, inSudoku s: Sudoku) -> Bool {
    return !doesSudoku(s: s, containMark: mark, inRow: row)
        && !doesSudoku(s: s, containMark: mark, inColumn: col)
        && !doesSudoku(s: s, containMark: mark, in3x3BoxWithRow: row, column: col)
}

/// Determine whether a specified mark already exists in a specified row
private func doesSudoku(s: Sudoku, containMark mark: Int, inRow row: Int) -> Bool {
    for col in 0..<9 {
        if s[row][col].isMarkedWithValue(value: mark) { return true }
    }
    return false
}

/// Determine whether a specified mark already exists in a specified column
private func doesSudoku(s: Sudoku, containMark mark: Int, inColumn col: Int) -> Bool {
    for row in 0..<9 {
        if s[row][col].isMarkedWithValue(value: mark) { return true }
    }
    return false
}

/// Determine whether a specified mark already exists in a specified 3x3 subgrid
private func doesSudoku(s: Sudoku, containMark mark: Int, in3x3BoxWithRow row: Int, column col: Int) -> Bool {
    let boxMinRow = (row / 3) * 3
    let boxMaxRow = boxMinRow + 2
    let boxMinCol = (col / 3) * 3
    let boxMaxCol = boxMinCol + 2
    
    for row in boxMinRow...boxMaxRow {
        for col in boxMinCol...boxMaxCol {
            if s[row][col].isMarkedWithValue(value: mark) { return true }
        }
    }
    return false
}
