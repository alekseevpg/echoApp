import Foundation
import Swinject

struct DIContainer {
    private var instance = Container() { c in
        c.register(EchoService.self) { _ in
            EchoService()
        }.inObjectScope(.container)
    }

    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return instance.resolve(serviceType)
    }

    static let Instance = DIContainer()

    private init() {
    }
}
