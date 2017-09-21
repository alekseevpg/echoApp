import Foundation
import UIKit
import SnapKit
import AVFoundation

class MainViewController: UIViewController, AVAudioPlayerDelegate {

    var echoService = DIContainer.Instance.resolve(EchoService.self)!

    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer?

    private lazy var recordButton: UIButton = UIButton()
    private lazy var playButton: UIButton = UIButton()
    private lazy var speedSwitch: UISwitch = UISwitch()
    private lazy var speedLabel: UILabel = UILabel()
    private lazy var indicatorView: UIActivityIndicatorView = UIActivityIndicatorView()

    private var audioSpeed: Float = 1 {
        didSet {
            if let player = audioPlayer {
                player.rate = audioSpeed
            }
        }
    }

    var recordingState: RecordingState = .disabled {
        didSet {
            recordButton.isEnabled = true
            recordButton.alpha = 1
            switch recordingState {
            case .disabled:
                recordButton.isEnabled = false
                recordButton.alpha = 0.5
                recordButton.setBackgroundImage(UIImage(named: "rec"), for: UIControlState())
            case .idle:
                recordButton.setBackgroundImage(UIImage(named: "rec"), for: UIControlState())
            case .recording:
                recordButton.setBackgroundImage(UIImage(named: "rec_active"), for: UIControlState())
            }
        }
    }

    var playingState: PlaybackState = .disabled {
        didSet {
            playButton.isEnabled = true
            playButton.alpha = 1
            switch playingState {
            case .disabled:
                playButton.isEnabled = false
                playButton.alpha = 0.5
                playButton.setBackgroundImage(UIImage(named: "play"), for: UIControlState())
            case .idle:
                playButton.setBackgroundImage(UIImage(named: "play"), for: UIControlState())
            case .playing:
                playButton.setBackgroundImage(UIImage(named: "play"), for: UIControlState())
            case .paused:
                playButton.setBackgroundImage(UIImage(named: "pause"), for: UIControlState())
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
        self.setupConstraints()

        checkRecordPermission { [unowned self] allowed in
            if allowed {
                self.prepareRecorder()
            } else {
                self.recordingState = .disabled
            }
        }
    }

    private func setupViews() {
        view.backgroundColor = .white

        view.addSubview(recordButton)

        playButton.addTarget(self, action: #selector(MainViewController.playBtnTapped), for: .touchUpInside)
        playingState = .disabled
        view.addSubview(playButton)

        let longTapGesture = UILongPressGestureRecognizer(target: self,
                action: #selector(MainViewController.recordButtonLongTapped(_:)))
        longTapGesture.minimumPressDuration = 0.1
        longTapGesture.delaysTouchesBegan = true
        recordButton.addGestureRecognizer(longTapGesture)

        speedLabel.text = "1.5x"
        speedLabel.font = UIFont.systemFont(ofSize: 15)
        speedLabel.textColor = .black
        view.addSubview(speedLabel)

        speedSwitch.addTarget(self, action: #selector(MainViewController.audioSpeedChanged(_:)), for: .valueChanged)
        view.addSubview(speedSwitch)

        indicatorView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(indicatorView)
    }

    private func setupConstraints() {
        recordButton.snp.makeConstraints { make in
            make.left.equalTo(view.snp.centerX).offset(10)
            make.top.equalTo(view.snp.centerY).offset(10)
            make.width.equalTo(82)
            make.height.equalTo(82)
        }

        playButton.snp.makeConstraints { make in
            make.right.equalTo(view.snp.centerX).offset(-10)
            make.top.equalTo(view.snp.centerY).offset(10)
            make.width.equalTo(82)
            make.height.equalTo(82)
        }

        speedSwitch.snp.makeConstraints { make in
            make.right.equalTo(recordButton.snp.right)
            make.top.equalTo(playButton.snp.bottom).offset(50)
        }

        speedLabel.snp.makeConstraints { make in
            make.centerY.equalTo(speedSwitch.snp.centerY)
            make.left.equalTo(playButton.snp.left)
        }

        indicatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    func audioSpeedChanged(_ switcher: UISwitch) {
        audioSpeed = !switcher.isOn ? 1 : 1.5
    }

    func playBtnTapped() {
        guard let player = audioPlayer else {
            return
        }
        switch playingState {
        case .idle:
            player.play()
            playingState = .playing
        case .playing:
            player.pause()
            playingState = .paused
        case .paused:
            player.play()
            playingState = .playing
        default:
            return
        }
    }

    func recordButtonLongTapped(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            audioRecorder.record()
            recordingState = .recording
        case .ended:
            audioRecorder.stop()
            indicatorView.startAnimating()
            echoService.echo(url: getFileUrl(with: "recording")) { [unowned self] data in
                self.indicatorView.stopAnimating()
                self.recordingState = .idle
                guard let data = data else {
                    return
                }
                do {
                    try data.write(to: self.getFileUrl(with: "echo"))
                    self.preparePlayer()
                    self.playingState = .idle
                } catch {
                    print("write error detected")
                }
            }
        default:
            return
        }
    }

    private func checkRecordPermission(callback: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission() {
        case AVAudioSessionRecordPermission.granted:
            callback(true)
        case AVAudioSessionRecordPermission.undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                callback(allowed)
            }
        default:
            callback(false)
        }
    }

    private func getFileUrl(with name: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("\(name).m4a")
    }

    private func prepareRecorder() {
        let recordSettings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                             AVSampleRateKey: 44100,
                                             AVNumberOfChannelsKey: 2,
                                             AVEncoderBitRateKey: 128000,
                                             AVLinearPCMBitDepthKey: 16,
                                             AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue]

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            try audioSession.setActive(true)

            let audioRecorder = try AVAudioRecorder(url: getFileUrl(with: "recording"), settings: recordSettings)
            audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
            self.audioRecorder = audioRecorder
            recordingState = .idle
        } catch let error {
            print(error)
        }
    }

    private func preparePlayer() {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: getFileUrl(with: "echo"))
            audioPlayer.delegate = self
            audioPlayer.enableRate = true
            audioPlayer.rate = audioSpeed
            audioPlayer.prepareToPlay()

            self.audioPlayer = audioPlayer
            playingState = .idle
        } catch let error {
            print("preparePlayer \(error)")
            playingState = .disabled
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingState = .idle
    }
}
