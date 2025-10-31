package services

import (
	"fmt"
	"os"
	"strings"
	"time"

	"rdr/scraper/internal/services/scrap"
	"rdr/scraper/internal/web/types"
)

func GetMeeting() (types.Meeting, error) {
	accessUrl := os.Getenv("ACCESS_URL")
	if accessUrl == "" {
		return types.Meeting{}, fmt.Errorf("ACCESS_URL não definida")
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
	christianLifeParts := parseStrongItems(strongChristianLifeItems, "christian_life")

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

func setSubparts(part *types.Part, subpartsText []string) {
	for _, subpartText := range subpartsText {
		part.SubParts = append(part.SubParts, &types.Part{
			Title: &subpartText,
		})
	}
}
