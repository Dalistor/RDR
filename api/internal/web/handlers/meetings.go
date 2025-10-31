package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"rdr/scraper/internal/web/services"
)

func GetMeeting(c *gin.Context) {
	meeting, err := services.GetMeeting()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, meeting)
}
