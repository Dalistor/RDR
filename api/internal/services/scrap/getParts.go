package scrap

import (
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

// GetByValuePattern extrai tags que correspondem a um padrão específico do valor dentro delas
func GetByValuePattern(doc *goquery.Document, tag string, pattern string) []string {
	var items []string

	doc.Find(tag).Each(func(i int, s *goquery.Selection) {
		text := strings.TrimSpace(s.Text())
		if text != "" && regexp.MustCompile(pattern).MatchString(text) {
			items = append(items, text)
		}
	})

	return items
}

// GetLinksByClass busca links que tenham uma classe específica e retorna os hrefs
func GetLinksByClass(doc *goquery.Document, className string) []string {
	var links []string

	doc.Find("a").Each(func(i int, s *goquery.Selection) {
		class, exists := s.Attr("class")
		if exists && strings.Contains(class, className) {
			href, hrefExists := s.Attr("href")
			if hrefExists && href != "" {
				links = append(links, href)
			}
		}
	})

	return links
}

// GetStrongInH3WithNumber busca tags strong que começam com número e estão dentro de h3 com classe específica
func GetStrongInH3WithNumber(doc *goquery.Document, h3Class string) []string {
	var items []string

	// Regex para verificar se o texto começa com número seguido de ponto
	numberPattern := regexp.MustCompile(`^\d+\.`)

	// Buscar h3 com a classe específica
	doc.Find("h3").Each(func(i int, h3 *goquery.Selection) {
		class, exists := h3.Attr("class")
		if exists && strings.Contains(class, h3Class) {
			// Dentro deste h3, buscar tags strong
			h3.Find("strong").Each(func(j int, strong *goquery.Selection) {
				text := strings.TrimSpace(strong.Text())
				if text != "" && numberPattern.MatchString(text) {
					items = append(items, text)
				}
			})
		}
	})

	return items
}
