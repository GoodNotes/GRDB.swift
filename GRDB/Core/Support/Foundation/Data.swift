// Import C SQLite functions
#if SWIFT_PACKAGE
import CSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// Data is convertible to and from DatabaseValue.
extension Data: DatabaseValueConvertible, StatementColumnConvertible {
    public init(sqliteStatement: SQLiteStatement, index: CInt) {
        if let bytes = sqlite3_column_blob(sqliteStatement, index) {
            let count = Int(sqlite3_column_bytes(sqliteStatement, index))
            self.init(bytes: bytes, count: count) // copy bytes
        } else {
            self.init()
        }
    }
    
    /// Returns a BLOB database value.
    public var databaseValue: DatabaseValue {
        DatabaseValue(storage: .blob(self))
    }
    
    /// Returns a `Data` from the specified database value.
    ///
    /// If the database value contains a data blob, returns it.
    ///
    /// If the database value contains a string, returns this string converted
    /// to UTF8 data.
    ///
    /// Otherwise, returns nil.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Data? {
        switch dbValue.storage {
        case .blob(let data):
            return data
        case .string(let string):
            // Implicit conversion from string to blob, just as SQLite does
            // See <https://www.sqlite.org/c3ref/column_blob.html>
            return string.data(using: .utf8)
        default:
            return nil
        }
    }
    
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        withUnsafeBytes {
            sqlite3_bind_blob(sqliteStatement, index, $0.baseAddress, CInt($0.count), SQLITE_TRANSIENT)
        }
    }
    
    /// Calls the given closure after binding a statement argument.
    ///
    /// The binding is valid only during the execution of this method.
    ///
    /// - parameter sqliteStatement: An SQLite statement.
    /// - parameter index: 1-based index to statement arguments.
    /// - parameter body: The closure to execute when argument is bound.
    func withBinding<T>(to sqliteStatement: SQLiteStatement, at index: CInt, do body: () throws -> T) throws -> T {
        try withUnsafeBytes {
            let code = sqlite3_bind_blob(
                sqliteStatement, index,
                $0.baseAddress, CInt($0.count), nil /* SQLITE_STATIC */)
            try checkBindingSuccess(code: code, sqliteStatement: sqliteStatement)
            return try body()
        }
    }
}
