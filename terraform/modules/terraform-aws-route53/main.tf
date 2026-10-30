# Zone DNS hébergée dédiée à un environnement (ex. dev.obszh.fr).
#
# La délégation depuis la zone racine (obszh.fr) se fait une fois, à la main :
# créer un enregistrement NS dans la zone racine pointant vers les name servers
# exposés par la sortie name_servers de ce module.

resource "aws_route53_zone" "this" {
  name = var.domain_name

  # Pas de force_destroy : une zone se supprime volontairement, jamais par accident.
  tags = merge(var.tags, { Name = var.domain_name })
}
