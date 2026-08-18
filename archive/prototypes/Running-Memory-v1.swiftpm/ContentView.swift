import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - 1. Enums & Models
enum ThoughtCategory: String, CaseIterable, Codable {
    case idea = "IDEAS"
    case todo = "TO-DOS"
    case podcastQuote = "PODCAST QUOTE"
    case audiobookQuote = "AUDIOBOOK QUOTE"
    case metaGlasses = "META GLASSES"
    case runLog = "RUN LOG"
    
    var icon: String {
        switch self {
        case .idea: return "lightbulb.fill"
        case .todo: return "checkmark.circle.fill"
        case .podcastQuote: return "podcast.side.front"
        case .audiobookQuote: return "book.closed.fill"
        case .metaGlasses: return "eyeglasses"
        case .runLog: return "figure.run"
        }
    }
    
    var color: Color {
        switch self {
        case .idea: return .yellow
        case .todo: return .cyan
        case .podcastQuote: return .orange
        case .audiobookQuote: return .pink
        case .metaGlasses: return .purple
        case .runLog: return .green
        }
    }
}

struct RunNote: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let pace: String
    let distance: String
    let heartRate: String
    let locationName: String
    let category: ThoughtCategory
}

// MARK: - 2. Main Dashboard View
struct ContentView: View {
    @State private var isRecording = false
    @State private var selectedNote: RunNote?
    
    @State private var notes: [RunNote] = [
        RunNote(text: "Idea for new podcast episode layout", pace: "5'12\"", distance: "3.42 mi", heartRate: "158 bpm", locationName: "Highgate Wood", category: .idea),
        RunNote(text: "Remember to review script drafts with Kate tonight", pace: "5'08\"", distance: "2.10 mi", heartRate: "162 bpm", locationName: "Queen's Park", category: .todo),
        RunNote(text: "Meta Glasses photo matched: Scenic turn at hilltop", pace: "4'58\"", distance: "4.10 mi", heartRate: "164 bpm", locationName: "Regent's Park", category: .metaGlasses),
        RunNote(text: "Saved audio clip from marathon audio book chapter", pace: "5'02\"", distance: "1.80 mi", heartRate: "155 bpm", locationName: "Hampstead Heath", category: .audiobookQuote),
        RunNote(text: "Legs feeling super strong through the 5k mark!", pace: "4'55\"", distance: "3.10 mi", heartRate: "165 bpm", locationName: "Regent's Park", category: .runLog)
    ]
    
    private let samplePool: [(String, ThoughtCategory)] = [
        ("New creative concept for upcoming holiday artwork piece", .idea),
        ("Remember to check recovery protein blend order", .todo),
        ("Meta Glasses captured stunning sunset photo on trail", .metaGlasses),
        ("Saved audio clip from marathon training podcast episode", .podcastQuote),
        ("Audiobook quote bookmark saved at Chapter 4", .audiobookQuote),
        ("Holding smooth, comfortable stride down back hill", .runLog)
    ]
    @State private var sampleIndex = 0
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                // Centered Bold Header
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("RUNNING")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.primary)
                            .tracking(-0.5)
                        
                        Text("MEMORY")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.green)
                            .tracking(-0.5)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // K.I.T.T. Voice PA Record Target
                Button(action: {
                    isRecording.toggle()
                    if !isRecording {
                        let sample = samplePool[sampleIndex % samplePool.count]
                        sampleIndex += 1
                        
                        let newNote = RunNote(
                            text: sample.0,
                            pace: "5'02\"",
                            distance: "3.85 mi",
                            heartRate: "160 bpm",
                            locationName: "Highgate Wood",
                            category: sample.1
                        )
                        notes.insert(newNote, at: 0)
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(isRecording ? .red : .green)
                        
                        Text(isRecording ? "TAP TO SAVE NOTE (30s)" : "TAP TO RECORD THOUGHT")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isRecording ? Color.red : Color.green.opacity(0.6), lineWidth: 1.5)
                    )
                }
                .padding(.horizontal)
                
                // Subheader Title
                HStack(alignment: .firstTextBaseline) {
                    Text("Today's Captures")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("(\(notes.count))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Clean Timeline List (Tapping opens Detail Modal with Stats & Share)
                List {
                    ForEach(notes) { note in
                        Button(action: { selectedNote = note }) {
                            HStack(alignment: .top, spacing: 14) {
                                
                                Image(systemName: note.category.icon)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(note.category.color)
                                    .padding(10)
                                    .background(note.category.color.opacity(0.15))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(note.text)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                    
                                    HStack(spacing: 6) {
                                        Text(note.category.rawValue)
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundColor(note.category.color)
                                        
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        
                                        Text("Pace: \(note.pace)")
                                            .foregroundColor(.secondary)
                                        
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        
                                        Text(note.locationName)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                }
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 6)
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        notes.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedNote) { note in
            MemoryCardDetailView(note: note, onDelete: { deletedNote in
                notes.removeAll { $0.id == deletedNote.id }
            })
        }
    }
}

// MARK: - 3. Memory Detail & Share Sheet View
struct MemoryCardDetailView: View {
    let note: RunNote
    var onDelete: ((RunNote) -> Void)?
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                // Header Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: note.category.icon)
                        Text(note.category.rawValue)
                    }
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(note.category.color)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(note.category.color.opacity(0.15))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Share Sheet Trigger Button
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(note.category.color)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // Map / Photo Container
                        ZStack(alignment: .bottomLeading) {
                            if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .frame(height: 160)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(note.category.color)
                                        Text(note.locationName)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    Text("GPS ROUTE SEGMENT")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                        Text(selectedImageData == nil ? "Add Photo" : "Change")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(20)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                        
                        // Transcribed Quote Container
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TRANSCRIPT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text("\"\(note.text)\"")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(.primary)
                                .italic()
                            
                            HStack {
                                Spacer()
                                Button(action: {}) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.circle.fill")
                                        Text("Play Audio")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(note.category.color)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Stats Metrics Bar
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("PACE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(note.pace)
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 25)
                            
                            VStack(spacing: 2) {
                                Text("DISTANCE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(note.distance)
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider().frame(height: 25)
                            
                            VStack(spacing: 2) {
                                Text("HEART RATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(note.heartRate)
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Delete Entry Button
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete Capture")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal)
                        .alert("Delete Memory?", isPresented: $showDeleteConfirm) {
                            Button("Delete", role: .destructive) {
                                onDelete?(note)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will permanently remove this voice capture and stats from your memory bank.")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Check out my Running Memory capture: \"\(note.text)\" at \(note.locationName) (Pace: \(note.pace), Distance: \(note.distance))"])
        }
        .onChange(of: selectedPhotoItem) { oldValue, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
}

// MARK: - 4. UIKit Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
