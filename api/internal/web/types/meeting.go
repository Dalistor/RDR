package types

type Meta struct {
	Date          string `json:"date"`
	InitialTime   string `json:"initial_time"`
	FinalTime     string `json:"final_time"`
	FinalComments string `json:"final_comments"`
}

type Part struct {
	Title    *string `json:"title,omitempty"`
	Time     *string `json:"time,omitempty"`
	SubParts []*Part `json:"sub_parts,omitempty"`
}

type Meeting struct {
	Meta *Meta `json:"meta,omitempty"`

	Treasures     []*Part `json:"treasures,omitempty"`
	Ministries    []*Part `json:"ministries,omitempty"`
	ChristianLife []*Part `json:"christian_life,omitempty"`
}
