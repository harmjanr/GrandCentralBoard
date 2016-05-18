//
//  HarvestWidgetBuilder.swift
//  GrandCentralBoard
//
//  Created by Karol Kozub on 2016-04-11.
//  Copyright © 2016 Oktawian Chojnacki. All rights reserved.
//

import GCBCore


final class HarvestWidgetBuilder: WidgetBuilding {
    let name = "harvest"

    func build(json: AnyObject) throws -> WidgetControlling {
        let settings = try HarvestWidgetSettings.decode(json)
        let source = HarvestSource(settings: settings)

        return HarvestWidget(source: source, numberOfDays: settings.numberOfDays)
    }
}
