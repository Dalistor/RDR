package main

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"rdr/scraper/cmd/settings"
	"rdr/scraper/internal/web/ulrs"
)

func loadEnv() error {
	err := godotenv.Load()
	if err != nil {
		return fmt.Errorf("Erro ao carregar o arquivo .env: %v", err)
	}

	log.Println("Arquivo .env carregado com sucesso")

	return nil
}

func main() {
	fmt.Println("\033[43m\033[30m Bem-vindo ao RDR scraper!\033[0m")

	if err := loadEnv(); err != nil {
		log.Fatal(err)
	}

	gin.SetMode(gin.ReleaseMode)

	router := gin.Default()
	router.Use(settings.Cors())

	ulrs.SetUrls(router)

	router.Run(":" + "12765")
}
