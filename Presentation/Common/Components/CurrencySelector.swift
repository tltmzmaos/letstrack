import SwiftUI

/// Reusable currency selector component
struct CurrencySelector: View {
    @Binding var selectedCurrency: Currency

    var body: some View {
        Menu {
            ForEach(Currency.allCases) { currency in
                Button {
                    selectedCurrency = currency
                } label: {
                    HStack {
                        Text("\(currency.symbol) \(currency.name)")
                        if currency == selectedCurrency {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(selectedCurrency.symbol)
                .font(.title2)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// Amount input field with currency selector
struct AmountInputField: View {
    @Binding var amountText: String
    @Binding var selectedCurrency: Currency
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack {
            CurrencySelector(selectedCurrency: $selectedCurrency)

            TextField("0", text: $amountText)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    @Previewable @State var currency: Currency = .usd
    CurrencySelector(selectedCurrency: $currency)
        .padding()
}
