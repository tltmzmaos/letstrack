import SwiftUI
import SwiftData

struct WalletsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var showingAddWallet = false
    @State private var selectedWallet: Wallet?

    var totalBalance: Decimal {
        wallets.filter { !$0.isArchived }.reduce(Decimal.zero) { $0 + $1.balance }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Total balance card
                    TotalBalanceCard(balance: totalBalance)
                        .padding(.horizontal)

                    // Wallets list
                    if wallets.isEmpty {
                        EmptyWalletsView()
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(wallets.filter { !$0.isArchived }) { wallet in
                                WalletCard(wallet: wallet)
                                    .onTapGesture {
                                        selectedWallet = wallet
                                    }
                            }
                        }
                        .padding(.horizontal)

                        // Archived wallets
                        let archivedWallets = wallets.filter { $0.isArchived }
                        if !archivedWallets.isEmpty {
                            DisclosureGroup {
                                LazyVStack(spacing: 12) {
                                    ForEach(archivedWallets) { wallet in
                                        WalletCard(wallet: wallet)
                                            .opacity(0.6)
                                            .onTapGesture {
                                                selectedWallet = wallet
                                            }
                                    }
                                }
                            } label: {
                                Text(String(localized: "wallet.archived"))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(String(localized: "wallet.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWallet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddWallet) {
                AddWalletView()
            }
            .sheet(item: $selectedWallet) { wallet in
                WalletDetailView(wallet: wallet)
            }
        }
    }
}

// MARK: - Total Balance Card

struct TotalBalanceCard: View {
    let balance: Decimal

    var body: some View {
        VStack(spacing: 8) {
            Text(String(localized: "wallet.total_balance"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(CurrencySettings.shared.defaultCurrency.format(balance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Wallet Card

struct WalletCard: View {
    @Bindable var wallet: Wallet

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: wallet.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: wallet.colorHex) ?? .accentColor)
                .frame(width: 50, height: 50)
                .background((Color(hex: wallet.colorHex) ?? .accentColor).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(wallet.name)
                        .font(.headline)

                    if wallet.isDefault {
                        Text(String(localized: "wallet.default"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                Text("\(wallet.transactionCount) " + String(localized: "wallet.transactions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(wallet.formattedBalance)
                .font(.headline)
                .foregroundColor(wallet.balance >= 0 ? .primary : .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Empty State

struct EmptyWalletsView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "wallet.no_wallets"), systemImage: "wallet.pass")
        } description: {
            Text(String(localized: "wallet.no_wallets_description"))
        }
    }
}

// MARK: - Add Wallet View

struct AddWalletView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedType: Wallet.WalletType = .bank
    @State private var initialBalance: String = ""
    @State private var selectedIcon: String = "creditcard.fill"
    @State private var selectedColor: String = "#007AFF"
    @State private var isDefault: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "wallet.name"), text: $name)

                    Picker(String(localized: "wallet.type"), selection: $selectedType) {
                        ForEach(Wallet.WalletType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: selectedType) { _, newType in
                        selectedIcon = newType.icon
                        selectedColor = newType.defaultColor
                    }

                    HStack {
                        Text(CurrencySettings.shared.defaultCurrency.symbol)
                        TextField(String(localized: "wallet.initial_balance"), text: $initialBalance)
                            .keyboardType(.decimalPad)
                    }

                    Toggle(String(localized: "wallet.set_as_default"), isOn: $isDefault)
                }

                Section(String(localized: "wallet.appearance")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Wallet.presetIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color(hex: selectedColor) ?? .accentColor : Color(.systemGray5))
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Wallet.presetColors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(String(localized: "wallet.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveWallet()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveWallet() {
        let wallet = Wallet(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorHex: selectedColor,
            balance: Decimal(string: initialBalance) ?? 0,
            isDefault: isDefault
        )

        modelContext.insert(wallet)
        dismiss()
    }
}

// MARK: - Wallet Detail View

struct WalletDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var wallet: Wallet

    @State private var showingDeleteAlert = false
    @State private var showingEditBalance = false
    @State private var newBalance: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: wallet.icon)
                            .font(.largeTitle)
                            .foregroundStyle(Color(hex: wallet.colorHex) ?? .accentColor)
                            .frame(width: 60, height: 60)
                            .background((Color(hex: wallet.colorHex) ?? .accentColor).opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(wallet.name)
                                .font(.title2.bold())

                            Text(wallet.formattedBalance)
                                .font(.headline)
                                .foregroundStyle(wallet.balance >= 0 ? .green : .red)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Toggle(String(localized: "wallet.default"), isOn: $wallet.isDefault)
                    Toggle(String(localized: "wallet.archived"), isOn: $wallet.isArchived)
                }

                Section {
                    Button {
                        newBalance = "\(wallet.balance)"
                        showingEditBalance = true
                    } label: {
                        Label(String(localized: "wallet.adjust_balance"), systemImage: "plusminus.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(String(localized: "wallet.delete"), systemImage: "trash")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "wallet.adjust_balance"), isPresented: $showingEditBalance) {
                TextField(String(localized: "wallet.balance"), text: $newBalance)
                    .keyboardType(.decimalPad)
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.save")) {
                    if let balance = Decimal(string: newBalance) {
                        wallet.balance = balance
                    }
                }
            }
            .alert(String(localized: "wallet.delete"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    modelContext.delete(wallet)
                    dismiss()
                }
            } message: {
                Text(String(localized: "wallet.delete_confirm"))
            }
        }
    }
}

#Preview {
    WalletsView()
        .modelContainer(for: [Wallet.self], inMemory: true)
}
