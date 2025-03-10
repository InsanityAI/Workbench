if Debug then Debug.beginFile "VotingDialogTest" end
OnInit.final(function(require)
    require "ChatSystem"
    require "VotingDialog"

    ChatCommandBuilder.create("voting", function()
        local votingDialog = VotingDialog.create({ ---@type VotingDialog
            title = "Voting Dialog!",
            votingDoneCallback = function(selectedOptions)
                for _, option in ipairs(selectedOptions) do
                    print("Selected Option '" .. option.name .. "'!")
                end
            end,
            commitButton = {
                hotkey = string.byte("D"),
                text = "Commit"
            },
            buttons = {
                {
                    hotkey = "A",
                    prefix = "Option A",
                    messageFormat = "[\x25s] \x25s",
                    options = {
                        {
                            name = "A-1",
                            previewCallback = function(player)
                                print("Preview A-1")
                            end
                        },
                        {
                            name = "A-2",
                            previewCallback = function(player)
                                print("Preview A-2")
                            end
                        },
                        {
                            name = "A-3",
                            previewCallback = function(player)
                                print("Preview A-3")
                            end
                        }
                    }
                },
                {
                    hotkey = "B",
                    prefix = "Option B",
                    messageFormat = "[\x25s] \x25s",
                    options = {
                        {
                            name = "B-1",
                            previewCallback = function(player)
                                print("Preview B-1")
                            end
                        },
                        {
                            name = "B-2",
                            previewCallback = function(player)
                                print("Preview B-2")
                            end
                        }
                    }
                },
                {
                    hotkey = "C",
                    prefix = "Option C",
                    messageFormat = "[\x25s] \x25s",
                    options = {
                        {
                            name = "C-1",
                            previewCallback = function(player)
                                print("Preview C-1")
                            end
                        }
                    }
                }
            }
        })

        votingDialog:Enqueue(SetUtils.getPlayersAll())
    end):description("Test voting dialog"):showInHelp():register()
end)
if Debug then Debug.endFile() end
