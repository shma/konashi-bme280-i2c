//
//  HexRepresentable.swift
//  konashichecker
//
//  データ型を人間にとってわかりやすい16進数にしてくれる拡張
//  https://www.pebblewind.com/entry/2017/09/12/174656
//  Copyright © 2019年 Matsuno Shunya. All rights reserved.
//

import Foundation

public protocol HexRepresentable {
    func hexDescription() -> String
}


extension UInt8 : HexRepresentable
{
    public func hexDescription() -> String {
        return String(format:"%02x", self)
    }
}

extension Int32 : HexRepresentable
{
    public func hexDescription() -> String
    {
        return String(format:"%08x", self)
    }
}

extension Collection where Iterator.Element : HexRepresentable {
    public func hexDescription() -> String {
        return self.map({ $0.hexDescription() }).joined()
    }
}

extension Data : HexRepresentable {
    public func hexDescription() -> String {
        return self.map({ String(format:"%02x", $0) }).joined()
    }
}
