package services

import (
	"fmt"
	"strings"
	"time"

	"rdr/scraper/internal/services/scrap"
	"rdr/scraper/internal/web/types"
)

func GetMeeting() (types.Meeting, error) {
	accessUrl := "https://wol.jw.org"
	if accessUrl == "" {
		// Retorna dados mockados quando ACCESS_URL não está definida (modo mobile)
		return getMockMeeting(), nil
	}

	url := fmt.Sprintf("%s/%s", accessUrl, "pt/wol/meetings/r5/lp-t/")
	doc, err := scrap.GetPage(url)
	if err != nil {
		return types.Meeting{}, err
	}

	links := scrap.GetLinksByClass(doc, "docClass-106")

	apostileLink := links[0]
	apostileUrl := fmt.Sprintf("%s%s", accessUrl, apostileLink)

	apostileDoc, err := scrap.GetPage(apostileUrl)
	if err != nil {
		return types.Meeting{}, err
	}

	strongTreasuresItems := scrap.GetStrongInH3WithNumber(apostileDoc, "du-color--teal-700")
	treasuresParts := parseStrongItems(strongTreasuresItems, "treasures")

	strongMinistriesItems := scrap.GetStrongInH3WithNumber(apostileDoc, "du-color--gold-700")
	ministriesParts := parseStrongItems(strongMinistriesItems, "ministries")

	strongChristianLifeItems := scrap.GetStrongInH3WithNumber(apostileDoc, "du-color--maroon-600")

	christianLifeParts := []*types.Part{}
	christianLifeParts = parseStrongItems(strongChristianLifeItems, "christian_life")

	// Adiciona "Presidente" como primeira parte
	presidentePart := &types.Part{
		Title: &[]string{"Presidente"}[0],
	}
	christianLifeParts = append([]*types.Part{presidentePart}, christianLifeParts...)

	return types.Meeting{
		Meta: &types.Meta{
			Date:          time.Now().Format("02/01/2006"),
			InitialTime:   "",
			FinalTime:     "",
			FinalComments: "",
		},
		Treasures:     treasuresParts,
		Ministries:    ministriesParts,
		ChristianLife: christianLifeParts,
	}, nil
}

func parseStrongItems(strongItems []string, partType string) []*types.Part {
	var parts []*types.Part
	for _, strongItem := range strongItems {
		part := &types.Part{
			Title: &strongItem,
		}

		if (partType == "treasures" || partType == "christian_life") && (!strings.Contains(strongItem, "Leitura da Bíblia") && !strings.Contains(strongItem, "Estudo bíblico de congregação")) {
			setSubparts(part, []string{
				"Presidente",
			})
		}

		if partType == "ministries" {
			setSubparts(part, []string{
				"Conselho",
				"Transição",
			})
		}

		if strings.Contains(strongItem, "3. Leitura da Bíblia") {
			setSubparts(part, []string{
				"Conselho",
				"Transição",
			})
		}

		parts = append(parts, part)
	}

	return parts
}

// getMockMeeting retorna dados mockados para uso no mobile quando ACCESS_URL não está definida
func getMockMeeting() types.Meeting {
	presidenteTitle := "Presidente"
	conselhoTitle := "Conselho"
	transicaoTitle := "Transição"

	treasuresParts := []*types.Part{
		{Title: &[]string{"1. Tenha uma vida feliz e saudável"}[0], SubParts: []*types.Part{{Title: &presidenteTitle}}},
		{Title: &[]string{"2. Joias espirituais"}[0], SubParts: []*types.Part{{Title: &presidenteTitle}}},
		{Title: &[]string{"3. Leitura da Bíblia"}[0], SubParts: []*types.Part{{Title: &conselhoTitle}, {Title: &transicaoTitle}}},
	}

	ministriesParts := []*types.Part{
		{Title: &[]string{"4. Cultivando o interesse"}[0], SubParts: []*types.Part{{Title: &conselhoTitle}, {Title: &transicaoTitle}}},
		{Title: &[]string{"5. Cultivando o interesse"}[0], SubParts: []*types.Part{{Title: &conselhoTitle}, {Title: &transicaoTitle}}},
		{Title: &[]string{"6. Discurso"}[0], SubParts: []*types.Part{{Title: &conselhoTitle}, {Title: &transicaoTitle}}},
	}

	presidentePart := &types.Part{
		Title: &presidenteTitle,
	}
	christianLifeParts := []*types.Part{
		presidentePart,
		{Title: &[]string{"7. Necessidades locais"}[0], SubParts: []*types.Part{{Title: &presidenteTitle}}},
		{Title: &[]string{"8. Estudo bíblico de congregação"}[0]},
	}

	return types.Meeting{
		Meta: &types.Meta{
			Date:          time.Now().Format("02/01/2006"),
			InitialTime:   "",
			FinalTime:     "",
			FinalComments: "",
		},
		Treasures:     treasuresParts,
		Ministries:    ministriesParts,
		ChristianLife: christianLifeParts,
	}
}

func setSubparts(part *types.Part, subpartsText []string) {
	for _, subpartText := range subpartsText {
		part.SubParts = append(part.SubParts, &types.Part{
			Title: &subpartText,
		})
	}
}
