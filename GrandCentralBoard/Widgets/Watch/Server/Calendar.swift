//
//  CalendarModel.swift
//  GrandCentralBoard
//
//  Created by Michał Laskowski on 07.04.2016.
//  Copyright © 2016 Oktawian Chojnacki. All rights reserved.
//

import Decodable

struct Calendar: Decodable {
    let name: String

    static func decode(json: AnyObject) throws -> Calendar {
        return try Calendar(name: json => "summary")
    }

    static func decodeFromData(data: NSData) throws -> Calendar {
        if let jsonResult = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? NSDictionary {
            return try Calendar.decode(jsonResult)
        }

        throw EventsError.WrongFormat
    }
}
