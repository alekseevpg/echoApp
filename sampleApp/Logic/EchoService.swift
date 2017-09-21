import Foundation
import Alamofire

class EchoService {

    private let serverAddress = "http://127.0.0.1:5000"

    func echo(url: URL, callback: @escaping (Data?) -> ()) {
        Alamofire.upload(
                multipartFormData: { multipartFormData in
                    multipartFormData.append(url, withName: "recording")
                },
                to: "\(serverAddress)/echo/",
                encodingCompletion: { encodingResult in
                    sleep(1)
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseData { response in
                            callback(response.data)
                        }
                    case .failure(let encodingError):
                        print(encodingError)
                        callback(nil)
                    }
                })
    }
}
