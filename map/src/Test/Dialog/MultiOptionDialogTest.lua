if Debug then Debug.beginFile "MultiOptionDialogTest" end
OnInit.final(function(require)
    require "ChatSystem"
    require "MultiOptionDialog"

    ChatCommandBuilder.create("multidialog", function()
        local multiOptionDialog = MultiOptionDialog.create()
        multiOptionDialog.commitButton = DialogButtonWrapper.create()
        multiOptionDialog.commitButton.text = "Done"
        multiOptionDialog.commitButton.hotkey = string.byte("D")
        multiOptionDialog.commitButton.callback = function(button, dialog, player)
            print("Commit Done!")
        end

        multiOptionDialog.callback = function(dialog, player, buttonChosenOptionPairs)
            print("Dialog done!")
        end

        multiOptionDialog.buttons[1] = MultiOptionDialogButton.create()

        multiOptionDialog.buttons[1].prefix = "Option A"
        multiOptionDialog.buttons[1].hotkey = "A"

        multiOptionDialog.buttons[1].options[1] = MultiOptionDialogButtonOption.create()
        multiOptionDialog.buttons[1].options[1].name = "1"
        multiOptionDialog.buttons[1].options[1].previewCallback = function(player)
            print("Preview A-1")
        end

        multiOptionDialog.buttons[1].options[2] = MultiOptionDialogButtonOption.create()
        multiOptionDialog.buttons[1].options[2].name = "2"
        multiOptionDialog.buttons[1].options[2].previewCallback = function(player)
            print("Preview A-2")
        end

        multiOptionDialog.buttons[1].options[3] = MultiOptionDialogButtonOption.create()
        multiOptionDialog.buttons[1].options[3].name = "3"
        multiOptionDialog.buttons[1].options[3].previewCallback = function(player)
            print("Preview A-3")
        end

        multiOptionDialog.buttons[2] = MultiOptionDialogButton.create()
        multiOptionDialog.buttons[2].prefix = "Option B"
        multiOptionDialog.buttons[2].hotkey = "B"

        multiOptionDialog.buttons[2].options[1] = MultiOptionDialogButtonOption.create()
        multiOptionDialog.buttons[2].options[1].name = "1"
        multiOptionDialog.buttons[2].options[1].previewCallback = function(player)
            print("Preview B-1")
        end

        multiOptionDialog.buttons[2].options[2] = MultiOptionDialogButtonOption.create()
        multiOptionDialog.buttons[2].options[2].name = "2"
        multiOptionDialog.buttons[2].options[2].previewCallback = function(player)
            print("Preview B-2")
        end

        multiOptionDialog.buttons[3] = MultiOptionDialogButton.create()
        multiOptionDialog.buttons[3].prefix = "Option C"
        multiOptionDialog.buttons[3].hotkey = "C"

        multiOptionDialog.buttons[3].options[1] = MultiOptionDialogButtonOption.create()
        multiOptionDialog.buttons[3].options[1].name = "1"
        multiOptionDialog.buttons[3].options[1].previewCallback = function(player)
            print("Preview C-1")
        end

        multiOptionDialog:Enqueue(SetUtils.getPlayersAll())
    end):description("Test multi option dialog"):showInHelp():register()
end)
if Debug then Debug.endFile() end
