package ulrs

import (
	"rdr/scraper/internal/web/handlers"

	"github.com/gin-gonic/gin"
)

func SetUrls(router *gin.Engine) {
	router.GET("/meeting", handlers.GetMeeting)
}
