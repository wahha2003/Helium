//
//  DropdownPicker.swift
//
//  Created by Fuuko on 24/02/22.
//

import SwiftUI

struct DropdownItem<T: Equatable>: Identifiable {
    let id = UUID()
    let label: String
    let tag: T
    
    init(_ label: String, tag: T) {
        self.label = label
        self.tag = tag
    }
}

struct DropdownPicker<T: Equatable>: View {
    @Binding var selection: T
    @State private var selectedIndex: Int? = nil
    private var dropdownItems: [DropdownItem<T>]

    init(selection: Binding<T>, items: @escaping () -> [DropdownItem<T>]) {
        self._selection = selection
        self.dropdownItems = items()
    }

    var body: some View {
        Menu {
            ForEach(dropdownItems.indices, id: \.self) { index in
                Button(action: {
                    selectedIndex = index
                    selection = dropdownItems[index].tag
                }) {
                    HStack {
                        Text(dropdownItems[index].label)
                        Spacer()
                        if selectedIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(selectedIndex == index ? .blue : .black)
            }
        } label: {
            HStack{
                Text(selectedIndex.map { dropdownItems[$0].label } ?? "Select")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Image(systemName: "chevron.down")
                    .font(Font.system(size: 20, weight: .bold))
            }
        }
        .onAppear {
            if let index = dropdownItems.firstIndex(where: { $0.tag == selection }) {
                selectedIndex = index
            } else {
                selectedIndex = 0
                selection = dropdownItems[0].tag
            }
        }
        .animation(nil)
    }
}