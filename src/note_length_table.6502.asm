;note length constants (aliases)
thirtysecond = $80
sixteenth = $81
eighth = $82
quarter = $83
half = $84
whole = $85
d_sixteenth = $86
d_eighth = $87
d_quarter = $88
d_half = $89
d_whole = $8A   ;don't forget we are counting in hex
t_quarter = $8B

note_length_table:
    .b $01   ;32nd note
    .b $02   ;16th note
    .b $04   ;8th note
    .b $08   ;quarter note
    .b $10   ;half note
    .b $20   ;whole note
             ;---dotted notes
    .b $03   ;dotted 16th note
    .b $06   ;dotted 8th note
    .b $0C   ;dotted quarter note
    .b $18   ;dotted half note
    .b $30   ;dotted whole note?
             ;---other
    .b $07   ;modified quarter to fit after d_sixteenth triplets