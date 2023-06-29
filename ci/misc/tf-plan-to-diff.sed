/^[[:space:]]{2}([-+~#])/ { s/^..// }      # remove 2 leading spaces in front of "-"/"+"/"~"/"#"
s@^-/\+@!@                                 # change a leading "-/+" to "!"
/^~/ { s/^/@@ /; s/$/ @@/ }                # when a leading "~" is present, add "@@" as line prefix and suffix
/^#.*will be created/          { s/^#/+/ } # highlight a comment line
/^#.*will be destroyed/        { s/^#/-/ } #            ditto
/^#.*must be replaced/         { s/^#/!/ } #            ditto
/^#.*will be updated in-place/ { s/^#/@@/; s/$/ @@/ } # ditto
