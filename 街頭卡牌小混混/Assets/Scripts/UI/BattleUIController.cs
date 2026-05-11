using UnityEngine;
using UnityEngine.UI;
using StreetCardBrawler.Cards;
using StreetCardBrawler.Combat;

namespace StreetCardBrawler
{
    public sealed class BattleUIController : MonoBehaviour
    {
        public PlayerFighter player;
        public EnemyFighter enemy;
        public CardDeckController deck;
        public Text playerHealthText;
        public Text enemyHealthText;
        public Text energyText;
        public Text statusText;
        public GameObject endPanel;
        public Text endText;
        public Button[] cardButtons;
        public Text[] cardLabels;

        private float statusClearTimer;

        private void Start()
        {
            if (player != null) player.PlayerDied += ShowDefeat;
            if (enemy != null) enemy.EnemyDied += ShowVictory;
            if (endPanel != null) endPanel.SetActive(false);
            Refresh();
            ShowStatus("Draw cards, close distance, fight");
        }

        private void Update()
        {
            RefreshStats();
            if (statusClearTimer > 0f)
            {
                statusClearTimer -= Time.deltaTime;
                if (statusClearTimer <= 0f && statusText != null)
                {
                    statusText.text = string.Empty;
                }
            }
        }

        public void Refresh()
        {
            RefreshStats();
            RefreshCards();
        }

        public void ShowStatus(string message)
        {
            if (statusText == null) return;
            statusText.text = message;
            statusClearTimer = 1.6f;
        }

        private void RefreshStats()
        {
            if (player != null)
            {
                playerHealthText.text = "Player HP " + player.health + "/" + player.maxHealth;
                energyText.text = "Energy " + player.energy + "/" + player.maxEnergy;
            }

            if (enemy != null)
            {
                enemyHealthText.text = "Thug HP " + enemy.health + "/" + enemy.maxHealth;
            }
        }

        private void RefreshCards()
        {
            if (deck == null || cardButtons == null || cardLabels == null) return;

            for (int i = 0; i < cardButtons.Length; i++)
            {
                CardData card = i < deck.Hand.Count ? deck.Hand[i] : null;
                if (cardButtons[i] != null) cardButtons[i].interactable = card != null;
                if (cardLabels[i] != null)
                {
                    cardLabels[i].text = card == null ? "Empty" : (i + 1) + "  " + card.cardName + "\nCost " + card.energyCost + "\n" + card.description;
                }
            }
        }

        private void ShowVictory()
        {
            deck.SetBattleOver(true);
            if (endPanel != null) endPanel.SetActive(true);
            if (endText != null) endText.text = "Victory\nStreet cleared";
        }

        private void ShowDefeat()
        {
            deck.SetBattleOver(true);
            if (endPanel != null) endPanel.SetActive(true);
            if (endText != null) endText.text = "Defeat\nTry another hand";
        }
    }
}
