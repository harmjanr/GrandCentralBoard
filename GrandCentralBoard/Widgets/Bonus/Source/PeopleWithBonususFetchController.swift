//
//  PeopleWithBonusesFetchController.swift
//  GrandCentralBoard
//
//  Created by Rafal Augustyniak on 07/04/16.
//

import Foundation
import GrandCentralBoardCore


enum PeopleWithBonususFetchControllerError: ErrorType {
    case IncorrectEmailAddress
    case NoAvatarURL
    case Cancelled
    case Unknown
}


final class PeopleWithBonusesFetchController {

    private let requestSending: RequestSending
    private let pageSize: Int
    private let preferredNumberOfPeople: Int
    private let dataDownloading: DataDownloading

    init(requestSending: RequestSending, dataDownloading: DataDownloading, pageSize: Int, preferredNumberOfPeople: Int) {
        self.requestSending = requestSending
        self.pageSize = pageSize
        self.preferredNumberOfPeople = preferredNumberOfPeople
        self.dataDownloading = dataDownloading
    }

    func fetchPeopleWithBonuses(completionBlock: (Result<[Person]>) -> Void) {
        fetchPeopleWithBonuses(startingFromDate: NSDate.init(), fetchedBonuses: [], completionBlock: { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case .Success(let people):
                strongSelf.fetchAvatarsForPeople(people, completionBlock: { result in
                    switch result {
                    case .Success(let people):
                        completionBlock(.Success(people))
                    case .Failure(let error):
                        completionBlock(.Failure(error))
                    }
                })
            case .Failure(let error):
                completionBlock(.Failure(error))
            }

        })
    }

    private func fetchPeopleWithBonuses(startingFromDate date: NSDate = NSDate.init(),
                                                         fetchedBonuses: [Bonus],
                                                         completionBlock: (Result<[Person]>) -> Void) {
        let requestTemplate = TimestampableRequestTemplate(requestTemplate: BonusesRequestTemplate(), date: date, take: self.pageSize)

        requestSending.sendRequestForRequestTemplate(requestTemplate) { [weak self] result in
            guard let strongSelf = self else {
                completionBlock(.Failure(PeopleWithBonususFetchControllerError.Cancelled))
                return
            }

            switch result {
            case .Success(let bonuses):
                var allBonuses: [Bonus] = fetchedBonuses
                allBonuses.appendContentsOf(bonuses)

                let people = allBonuses.uniqueReceivers(strongSelf.preferredNumberOfPeople)

                if people.count >= strongSelf.preferredNumberOfPeople || bonuses.count < strongSelf.pageSize {
                    completionBlock(.Success(Array(people)))
                } else if let lastBonus = bonuses.last {
                    strongSelf.fetchPeopleWithBonuses(startingFromDate: lastBonus.date, fetchedBonuses: allBonuses, completionBlock: completionBlock)
                }

            case .Failure(let error):
                completionBlock(.Failure(error))
            }
        }
    }

    private func fetchAvatarsForPeople(people: [Person], completionBlock: Result<[Person]> -> Void) {
        var peopleWithImages: [Person]? = [Person]()
        var groupError: ErrorType?

        let group = dispatch_group_create()
        people.forEach { person in
            dispatch_group_enter(group)
            updatePersonWithImageFromNetwork(person, completionBlock: { result in
                switch result {
                case .Success(let personWithImage):
                    peopleWithImages?.append(personWithImage)
                case .Failure(let error):
                    peopleWithImages = nil
                    groupError = error
                }
                dispatch_group_leave(group)
            })
        }

        dispatch_group_notify(group, dispatch_get_main_queue()) {
            if let peopleWithImages = peopleWithImages {
                completionBlock(.Success(peopleWithImages))
            } else {
                completionBlock(.Failure(groupError ?? PeopleWithBonususFetchControllerError.Unknown))
            }
        }
    }

    private func updatePersonWithImageFromNetwork(person: Person, completionBlock: (Result<Person>) -> Void) {

        guard let avatarPath = person.avatarPath else {
            completionBlock(.Failure(PeopleWithBonususFetchControllerError.NoAvatarURL))

            return
        }

        dataDownloading.downloadImageAtPath(avatarPath) { result in
            switch result {
            case .Success(let image):
                completionBlock(.Success(person.copyWithImage(image)))
            case .Failure(let error):
                completionBlock(.Failure(error))
            }
        }
    }
}


extension SequenceType where Generator.Element == Bonus {

    func uniqueReceivers(maximumNumberOfReceivers: Int) -> [Person] {
        return reduce([Person](), combine: { people, bonus in
            if people.count >= maximumNumberOfReceivers {
                return people
            } else {
                var receiver = bonus.receiver
                if people.contains(receiver) {
                    return people
                } else {
                    var mutablePeople = people
                    receiver = receiver.copyWithLastBonusDate(bonus.date)
                    mutablePeople.append(receiver)
                    return mutablePeople
                }
            }
        })
    }

}