import SwiftUI

/// Full profile screen. Accept/Decline here writes to the DB and updates this
/// screen instantly; the list card reflects the same status on back because both
/// read the same `MatchProfile` object.
struct MatchDetailView: View {
    @State private var viewModel: MatchDetailViewModel

    init(viewModel: MatchDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var profile: MatchProfile { viewModel.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                decisionSection
                detailsSection
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle(profile.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't save", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            RemoteImage(url: profile.largeImageURL)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            VStack(spacing: Theme.Spacing.xs) {
                Text(profile.fullName)
                    .font(.title2.bold())
                Text("\(profile.age) years · \(profile.location)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var decisionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Your decision")
                .font(.headline)
            DecisionActionBar(decision: profile.decision, prominent: true) { decision in
                viewModel.setDecision(decision)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Details")
                .font(.headline)

            DetailRow(icon: "envelope", label: "Email", value: profile.email)
            DetailRow(icon: "phone", label: "Phone", value: profile.phone)
            DetailRow(icon: "iphone", label: "Cell", value: profile.cell)
            DetailRow(icon: "flag", label: "Nationality", value: profile.nationality)
            DetailRow(icon: "person", label: "Gender", value: profile.gender.capitalized)
            DetailRow(icon: "mappin.and.ellipse", label: "Location", value: profile.location)
            DetailRow(icon: "calendar", label: "Registered", value: profile.registeredDate.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}

/// One labelled row in the details section.
private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.isEmpty ? "—" : value)
                    .font(.body)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }
}
